// This is a roxen module. Copyright � 1998 - 2000, Roxen IS.

inherit "module";

constant cvs_version = "$Id: pathinfo.pike,v 1.14 2000/06/19 16:32:30 grubba Exp $";
constant thread_safe = 1;

#ifdef PATHINFO_DEBUG
# define PATHINFO_WERR(X) werror("PATHINFO: "+X+"\n");
#else
# define PATHINFO_WERR(X)
#endif

constant module_type = MODULE_LAST;
constant module_name = "Path info support";
constant module_doc  = #"\
Support for \"path info\" style URLs, e.g. URLs that got a path like
<tt>/index.html/a/b</tt>, where <tt>/index.html</tt> is an existing
file, but <tt>/index.html/a</tt> and <tt>/index.html/a/b</tt> aren't.
In this case <tt>/index.html</tt> will be fetched, and the rest,
<tt>/a/b</tt> is made available in the RXML variable page.pathinfo.";

/* #define PATHINFO_LINEAR */

mapping|int last_resort(object id)
{
  PATHINFO_WERR(sprintf("Checking %O...", id->not_query));
  if (id->misc->path_info) {
    // Already been here...
    PATHINFO_WERR(sprintf("Been here, done that."));
    return 0;
  }

  string query = id->not_query;
#ifndef PATHINFO_LINEAR
  array(int) offsets = Array.map(query/"/", sizeof);

  int sum = 0;
  int i;
  for (i=0; i < sizeof(offsets); i++) {
    sum = (offsets[i] += sum) + 1;
  }

  int lo = (offsets[0] == 0);   // Skip testing the empty string.
  int hi = sizeof(offsets) - 1;

  while(lo <= hi) {             // Don't let the beams cross.
    int probe = (lo + hi + 1)/2;
    string file = query[..offsets[probe]-1];

    PATHINFO_WERR(sprintf("Trying %O...", file));

    /* Note: Zapps id->not_query. */
    array st = id->conf->stat_file(file, id);
    if (st) {
      if (st[1] >= 0) {
        // Found a file!
        id->misc->path_info = query[offsets[probe]..];
        id->not_query = file;
        PATHINFO_WERR(sprintf("Found: %O:%O",
			      id->not_query, id->misc->path_info));
        return 1;       // Go through id->handle_request() one more time...
      }
      PATHINFO_WERR(sprintf("Directory: %O", file));
      /* Hm. Lets try this: */
      id->misc->path_info = query[offsets[probe]+1..];
      id->not_query = file+"/";
      lo = probe + 1;
    } else {
      hi = probe - 1;
    }
  }
#else /* PATHINFO_LINEAR */
  string pi = "";
  while( (search( query[1..], "/" ) != -1) && strlen( query ) > 0 )
  {
    query = reverse(query);
    string add_path_info;
    sscanf( query, "%[^/]/%s", add_path_info, query );
    query = reverse( query );
    pi = "/"+reverse( add_path_info )+pi;
    id->misc->path_info = pi;
    PATHINFO_WERR(sprintf("Trying: %O (%O)", query, pi));
    array st = id->conf->stat_file( query, id );
    if( st && (st[ ST_SIZE ] > 0))
    {
      id->not_query = query;
      PATHINFO_WERR(sprintf("Found: %O:%O",
			    id->not_query, id->misc->path_info));
      return 1;
    }
  }
#endif /* !PATHINFO_LINEAR */
  return 0;
}
