// This is a roxen module. Copyright � 2001 - 2009, Roxen IS.
//

#define _error id->misc->defines[" _error"]
//#define _extra_heads id->misc->defines[" _extra_heads"]

#include <module.h>
inherit "module";

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Tags: Session tag module";
constant module_doc  = #"\
This module provides the session tag which provides a variable scope
where user session data can be stored.";

protected string shared_db;
protected int db_ok;

protected void create (Configuration conf)
{
  defvar ("enable-shared-db", 0, "Enabled shared storage",
	  TYPE_FLAG, #"\
<p>Whether to store sessions in a database that can be shared between
servers.</p>

<p>Normally sessions are cached in RAM and are shifted out to disk
only when they have been inactive for some time. Enabling shared
storage disables all RAM caching, to make the sessions work across
servers in e.g. a round-robin load balancer. The drawback is more
expensive session handling.</p>");

  defvar ("shared-db", Variable.DatabaseChoice (
	    "shared", 0, "Shared database", #"\
The database to store sessions in. A table called \"session_cache\"
will be created in it."))
    ->set_invisibility_check_callback (lambda () {
					 return !query ("enable-shared-db");
				       });
  defvar ("use-prestate", 0,
	  "Use prestate to verify cookie",
	  TYPE_FLAG,
	  "If set to Yes, a redirect will be issued so that the request "
	  "will contain a prestate, that will be checked against the "
	  "cookie value. And it will mean that there will be two requests "
	  "in order for force-session-id to complete for clients that supports "
	  "cookies. For client that don't support cookies there will be one "
	  "request, and it affects SEO due to the redirect that will serve the "
	  "same page but with another url."
	  );
}

void start() {
  query_tag_set()->prepare_context=set_entities;
  shared_db = query ("enable-shared-db") && query ("shared-db");
  if (shared_db)
    db_ok = cache.setup_session_table (shared_db);
  else
    db_ok = 1;
}

string status()
{
  if (!db_ok)
    return "<font color='red'>"
      "Not working - cannot connect to shared database."
      "</font>\n";
}


// --- &client.session; ----------------------------------------

class EntityClientSession {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable = 0;
    if( query("use-prestate") ) {
      multiset prestates = filter(c->id->prestate,
				  lambda(string in) {
				  return has_prefix(in, "RoxenUserID="); } );

      // If there is both a cookie and a prestate, then we're in the process of
      // deciding session variable vehicle, and should thus return nothing.
      if(c->id->cookies->RoxenUserID && sizeof(prestates))
	return RXML.nil;
      // If there is a UserID cookie, use that as our session identifier.
      if(c->id->cookies->RoxenUserID)
	return ENCODE_RXML_TEXT(c->id->cookies->RoxenUserID, type);

      // If there is a RoxenUserID-prefixed prestate, use the first such
      // prestate as session identifier.
      if(sizeof(prestates)) {
	string session = indices(prestates)[0][12..];
	if(sizeof(session))
	  return ENCODE_RXML_TEXT(session, type);
      }
    } else {
      if ( c->id->cookies->RoxenUserID ) {
	return ENCODE_RXML_TEXT(c->id->cookies->RoxenUserID, type);
      }
    }
    // Otherwise return nothing.
    return RXML.nil;
  }
}

mapping session_entity = ([ "session":EntityClientSession() ]);

void set_entities(RXML.Context c) {
  c->extend_scope("client", session_entity + ([]));
}


// --- RXML Tags -----------------------------------------------

class TagSession {
  inherit RXML.Tag;
  constant name = "session";
  mapping(string:RXML.Type) req_arg_types = ([ "id" : RXML.t_text(RXML.PEnt) ]);

  class Frame {
    inherit RXML.Frame;
    mapping vars;
    string scope_name;

    array do_enter(RequestID id) {
      if (!db_ok) run_error ("Shared db not set up.\n");
      NOCACHE();
      vars = cache.get_session_data(args->id, shared_db) || ([]);
      scope_name = args->scope || "session";
    }

    array do_return(RequestID id) {
      result = content;
      if(!sizeof(vars)) return 0;
      int timeout;
      if (args->life) timeout = (int) args->life + time (1);
      else if (shared_db) timeout = 900 + time (1);
      cache.set_session_data(vars, args->id, timeout,
			     shared_db || !!args["force-db"] );
    }
  }
}

class TagClearSession {
  inherit RXML.Tag;
  constant name = "clear-session";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([ "id" : RXML.t_text(RXML.PEnt) ]);

  class Frame {
    inherit RXML.Frame;

    array do_enter(RequestID id) {
      if (!db_ok) run_error ("Shared db not set up.\n");
      NOCACHE();
      cache.clear_session(args->id, shared_db);
    }
  }
}

class TagForceSessionID {
  inherit RXML.Tag;
  constant name = "force-session-id";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  mapping(string:RXML.Type) opt_arg_types = ([
    "secure":RXML.t_text(RXML.PEnt),
    "httponly":RXML.t_text(RXML.PEnt),
  ]);

  class Frame {
    inherit RXML.Frame;

    array do_enter(RequestID id) {
      if( query("use-prestate") ) {
	int prestate = sizeof(filter(id->prestate,
				     lambda(string in) {
				       return has_prefix(in, "RoxenUserID");
				     } ));

	string path_info = id->misc->path_info || "";

	// If there is no ID cooke nor prestate, redirect to the same page
	// but with a session id prestate set.
	if(!id->cookies->RoxenUserID && !prestate) {
	  multiset orig_prestate = id->prestate;
	  string session_id = roxen.create_unique_id();
	  id->prestate += (< "RoxenUserID=" + session_id >);

	  mapping r = Roxen.http_redirect(id->not_query + path_info, id, 0,
					  id->real_variables);
	  if (r->error)
	    RXML_CONTEXT->set_misc (" _error", r->error);
	  if (r->extra_heads)
	    RXML_CONTEXT->extend_scope ("header", r->extra_heads);

	  // Don't trust that the user cookie setting is turned on. The effect
	  // might be that the RoxenUserID cookie is set twice, but that is
	  // not a problem for us.
	  // NB: Inlined call of Roxen.http_roxen_id_cookie() below.
	  Roxen.set_cookie(id, "RoxenUserId", session_id, 3600*24*365*2,
			   UNDEFINED, "/", args->secure, args->httponly);
	  id->prestate = orig_prestate;
	  return 0;
	}

	// If there is both an ID cookie and a session prestate, then the
	// user does accept cookies, and there is no need for the session
	// prestate. Redirect back to the page, but without the session
	// prestate. 
	if(id->cookies->RoxenUserID && prestate) {
	  multiset orig_prestate = id->prestate;
	  id->prestate = filter(id->prestate,
				lambda(string in) {
				  return !has_prefix(in, "RoxenUserID");
				} );
	  mapping r = Roxen.http_redirect(id->not_query + path_info, id, 0,
					  id->real_variables);
	  id->prestate = orig_prestate;
	  if (r->error)
	    RXML_CONTEXT->set_misc (" _error", r->error);
	  if (r->extra_heads)
	    RXML_CONTEXT->extend_scope ("header", r->extra_heads);
	  return 0;
	}
      } else {
	if ( !id->cookies->RoxenUserID ) {
	  string session_id = roxen->create_unique_id();
	  // NB: Inlined call of Roxen.http_roxen_id_cookie() below.
	  Roxen.set_cookie(id, "RoxenUserId", session_id, 3600*24*365*2,
			   UNDEFINED, "/", args->secure, args->httponly);
	  id->cookies->RoxenUserID = session_id;
	  return 0;
	}
      }
    }
  }
}


// --- Documentation  ------------------------------------------

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc = ([
  "session":#"<desc type='cont'><p>Creates a session bound scope. The session is
identified by a session key, given as an argument to the session tag.
The session key could be e.g. a value generated by
<ent>roxen.unique-id</ent> which is then transported by form
variables. An alternative which often is more convenient is to use the
variable client.session (provided by this module) together with the
<tag>force-session-id</tag> tag and the feature to set unique browser
id cookies in the http protocol module (located under the server ports
tab).</p></desc>

<attr name='id' value='string' required='1'><p>The key that identifies
the session. Could e.g. be a name, an IP adress, a cookie or the value
of the special variable client.session provided by this module (see
above).</p></attr>

<attr name='life' value='number' default='900'><p>Determines how many
seconds the session is guaranteed to persist on the server side.</p>

<p>If the module isn't configured to use a shared database, then
values over 900 means that the session variables will be moved to a
disk based database when they have not been used within 900
seconds.</p></attr>

<attr name='force-db'><p>If used, the session variables will be
immediatly written to the database. Otherwise session variables are
only moved to the database when they have not been used for a while
(given that they still have \"time to live\", as determined by the
life attribute).</p>

<p>Setting this flag will increase the integrity of the session, since
the variables will survive a server reboot, but it will also decrease
performance somewhat.</p>

<p>If the module is configured to use a shared database then sessions
are always written immediately, regardless of this flag.</p></attr>

<attr name='scope' value='name' default='session'><p>The name of the
scope that is created inside the session tag.</p></attr>
",

  // ------------------------------------------------------------


  "clear-session":#"<desc tag='tag'><p>Clear a session from all its content.</p></desc>

<attr name='id' value='string' required='required'>
<p>The key that identifies the session.</p></attr>",

  // ------------------------------------------------------------

  "&client.session;":#"<desc type='entity'> <p><short>Contains a session key for the user or
nothing.</short> The session key is primary taken from the RoxenUserID
cookie. If there is no such cookie it will return the value in the
prestate that begins with \"RoxenUserID=\" if the module is configured to use prestate.
Also, if the module is configured to use prestate and both the cookie and such a prestate
exists the client.session variable will be empty.
However the module is configured to set the cookie, this approach allows the 
client.session variable to be used together with <tag>force-session-id</tag>.
Note that the Session tag module must be loaded for this entity to exist.</p></desc>",

  // ------------------------------------------------------------

  "force-session-id":#"<desc tag='tag'><p>Forces a session id to be set in the variable
client.session. The heuristics is as follows: If the RoxenUserID
cookie is set, use its value. Then, depending on the settings of this module, there are two
ways the session cookie is set:</p>
  <list type='ul'>
    <item><p>If no RoxenUserID cookie exists, headers to set the cookie is generated. The client.session variable is set and usable immediately during the request from then on. If the client do not support cookies or has cookies turned off, each request the force-session-id tag is used, the session key will have a different value. This is the default behavior. If this approach is
undesirable, there is an alternative way next.</p></item>
    <item><p>If no RoxenUserID cookie exist, a redirect to the same page but with a prestate containing a newly generated session key together with a Set-Cookie header with the same key as value. If both the RoxenUserID cookie and the session prestate is set, redirect back to the same page without any session prestate set. I.e. 2 requests for client that supports cookies, and only one request for clients that don't. The module must be configured to do these redirects.</p></item>
  </list>

<p>The RoxenUserID cookie can  be set automatically by the HTTP protocol module. Look
at the option to enable unique browser id cookies under the server ports tab.</p>

<ex-box><force-session-id/>
<if variable='client.session'>
  <!-- RXML code that uses &client.session;, e.g. as follows: -->
  <session id='&client.session;'>
    ...
  </session>
</if>
</ex-box>

<ex-box><!-- To verify that client supports cookies on the server side: -->
<nocache>
  <if variable=\"form.test-cookie = 1\">
    <if variable=\"cookie.testing_cookie = 1\">
      Cookies work
    </if>
    <else>
     Your browser do not support cookies.
    </else>
  </if>
  <else>
    <set-cookie name=\"testing_cookie\" value=\"1\"/>
    <redirect to=\"&page.path;?test-cookie=1\"/>
  </else>
</nocache>
</ex-box>
</desc>

<attr name='secure'>
  <p>If this attribute is present the session cookie will be set with the Secure
  attribute. The Secure flag instructs the user agent to use only (unspecified)
  secure means to contact the origin server whenever it sends back the session
  cookie. If the browser supports the secure flag, it will not send the session
  cookie when the request is going to an HTTP page.</p>
</attr>

<attr name='httponly'>
  <p>If this attribute is present the session cookie will be set with
  the HttpOnly attribute. If the browser supports the HttpOnly flag,
  the session cookie will be secured from being accessed by a client
  side script.</p>
</attr>
",

]);
#endif
