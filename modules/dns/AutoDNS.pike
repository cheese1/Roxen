#include <module.h>
#include <roxen.h>
#include <stdio.h>
inherit "module";
inherit "roxenlib";

string host_ip_no;

#define ZTTL     "Zone TTL Value"
#define ZREFRESH "Zone Refresh Time"
#define ZRETRY   "Zone Failed-Refresh Retry Time"
#define ZEXPIRE  "Zone Expire Time"
#define DBURL    "Database URL"
#define NSDOMAIN "Name Server Domain"

#define TMPFILENAME  "/tmp/new-dns-hosts"

void create()
{ defvar("DNS File", "/tmp/test-dns-hosts",
         "DNS File", TYPE_STRING,
         "The name of the file where the DNS server (typically "
         "<TT>in.named</TT>) expects to find the DNS zone master data.");

  defvar(DBURL, "mysql://auto:site@kopparorm.idonex.se/autosite",
         DBURL, TYPE_STRING,
         "The SQL database URL.");

  defvar(NSDOMAIN, "idonex.se",
         NSDOMAIN, TYPE_STRING,
         "The name of the domain in which the name server operates.");

  defvar(ZTTL, "1 day",
         ZTTL, TYPE_MULTIPLE_STRING,
         "Time-To-Live for a resource record in a cache?",
         ({ "12 hours", "1 day", "2 days", "3 days", "5 days", "1 week" })
        );

  defvar(ZREFRESH, "30 minutes",
         ZREFRESH, TYPE_MULTIPLE_STRING,
         "How long does a cached resource record last in a secondary server?",
          ({ "15 minutes", "30 minutes", "1 hour", "2 hours",
             "3 hours", "6 hours" })
        );

  defvar(ZRETRY, "5 minutes",
         ZRETRY, TYPE_MULTIPLE_STRING,
         "How long should a secondary server wait before retrying after "
         "failure to complete a refresh?",
         ({ "2 minutes", "5 minutes", "10 minuters", "15 minutes" })
        );

  defvar(ZEXPIRE, "1 week",
         ZEXPIRE, TYPE_MULTIPLE_STRING,
         "How long, at most, should secondary servers remember resource "
         "records for this domain if the refresh keeps failing?",
         ({ "1 day", "2 days", "3 days", "5 days", "1 week", "2 weeks" })
        );

  roxen->set_var("AutoDNS_hook", this_object());
}

int query_timeunit(string var, int defaultvalue)
{ int x; string value = query(var); string dummy;
  if (sscanf(value, "%d w%s", x, dummy) == 2) return x * 3600 * 24 * 7;
  if (sscanf(value, "%d d%s", x, dummy) == 2) return x * 3600 * 24;
  if (sscanf(value, "%d h%s", x, dummy) == 2) return x * 3600;
  if (sscanf(value, "%d m%s", x, dummy) == 2) return x * 60;
  if (sscanf(value, "%d s%s", x, dummy) == 2) return x;
  return defaultvalue;
}

array register_module()
{ return ({ MODULE_PARSER, "AutoSite DNS Administration Module", "", 0, 1 });
}

string database_status
       = "will try to connect.";

string dns_update_status
       = "none since restart.";

string status()
{ return "<B>DNS Administration Status</B>\n<DL>"
       + "\n <DT>Database Status:<DD>" +database_status
       + "\n <DT>DNS Update:<DD>" + dns_update_status
       + "\n</DL>\n";
}

object database;

int update_scheduled = 0;

int last_update_time = 0;

void do_update()
// Update the DNS master file from the DOMAINS table.
{ if (!database)
  { // If the database is not available, leave the
    // update_schduled variable in its current state,
    // return for now, and let the update take until
    // the next time start() manages to open a connection
    // to the database.
    dns_update_status = "<P><B>DNS Update</B>: pending. Database presently unavailable.";
    return;
  }
  string fname = query("DNS File");
  object data  = database->big_query(
       "SELECT rr_owner,rr_type,rr_value,customer_id FROM dns ORDER BY customer_id");
  object file  = Stdio.FILE(TMPFILENAME, "wct");
  object row;

  if (!data)
  { dns_update_status = "no domains found in database.";
    call_out(do_update, 300); // try again in 5 minutes.
    return;
  }

  if (!file)
  { dns_update_status = "unable to write zone master file.";
    call_out(do_update, 300); // try again in 5 minutes.
    return;
  }

  int    ttl     = query_timeunit(ZTTL, 50000);
  string nsdomain= query(NSDOMAIN);
  string hostname= gethostname();

  file->write(";;; This file is automatically generated from the DOMAINS\n");
  file->write(";;; database in Database. Do not edit manually.\n");
  file->write("@       " + ttl + " IN SOA " + hostname + "." + nsdomain +
         ". hostmaster." + nsdomain + ". " 
         "\n                  " + time() + " ;; Serial"
         "\n                  " + query_timeunit(ZREFRESH, 2000) + "   ;; Refresh"
         "\n                  " + query_timeunit(ZRETRY, 500) + "    ;; Retry"
         "\n                  " + query_timeunit(ZEXPIRE, 500000) + " ;; Expire"
         "\n                  " + ttl + "  ;; Zone Minimum TTL\n");
  file->write("              IN NS  " + hostname + "." + nsdomain + ".\n");
  file->write("              IN MX  10 foo.se\n" );
  file->write("              IN A   " + host_ip_no + "\n");
  file->write("www           IN A   " + host_ip_no + "\n");

  int    customer_id = 0;

  while (row = data->fetch_row())
  { string dummy;

    string rr_owner = row[0];
    string rr_type  = row[1];
    string rr_value = row[2];

    // If there is a new customer, look up the name and add
    // a comment in the zonemaster file.

    if (row[3] &&
        customer_id != row[3])
    { // New customer.

      customer_id = row[3];

      object q = database->big_query(
         "SELECT name FROM customers WHERE id=" + customer_id);

      array customer_info = q->fetch_row();

      if (customer_info)
         file->write("\n;;; Data for customer #" + customer_id +
                " '" + customer_info[0] + "'\n");
      else
         file->write("\n;;; Data for customer #" + customer_id + "\n");
    }

    // Now generate the resource record (RR).

    switch (rr_type) // Check if we need to supply default values
                     // for the rr_value field.
    { case "A":
        if (rr_value == "" || rr_value == 0)
        {
          // If no value is given for the A-RR, assume that
          // the domain is handled by the same machine as
          // the AutoSite server runs on.

          rr_value = host_ip_no;
        }
        break;

      case "MX":
        if (rr_value == "" || rr_value == 0)
        {
          // If no machine is specified as mail exchanger,
          // assume that the mail will be handled by the
          // AutoSite SMTP server.

          rr_value = "10 " + rr_owner;
        }
        else if (sizeof(rr_value / " ") == 1)
        {
          // If there is only one argument, assume that the argument
          // is the name of the mail exchanger, and insert a priority
          // of 10.

          rr_value = "10 " + rr_value;
        }
        break;
    }

    while (1)
    { if (rr_value && rr_owner && rr_type)
      { int i;

        file->write(rr_owner + ". ");

        for(i = sizeof(rr_owner); i < 23; ++i) file->write(" ");

        file->write(ttl + " IN " + rr_type);

        for(i = sizeof(rr_type); i < 5; ++i) file->write(" ");

        file->write(" " + rr_value + "\n");

        if (rr_type == "MX") // Automatically generate a CNAME
                             // for WWW on same machine as
                             // mail exchanger.
        { rr_type = "CNAME";
          rr_value = rr_owner;
          rr_owner = "www." + rr_owner;
          continue;
        }
      }
      break;
    }
  }
  file->close();
  dns_update_status = "completed " + ctime(time())[4..];

  if (!mv(TMPFILENAME, fname))
  { dns_update_status += ", but failed to install new zone master file as '" +
                fname + "'";
    call_out(do_update, 900); // try again in 15 minutes
    return;
  }

  last_update_time = time();
  update_scheduled = 0;
}

void update()
{ // Schedule an update if one is not already scheduled.
  if (update_scheduled) return;
  update_scheduled = 1;
  call_out(do_update, 60);
}

string tag_update()
{
  update();
  return "DNS configuration update initiated.";
}

mapping query_tag_callers()
{
  return ([ "autosite-dns-update" : tag_update ]);
}



void start()
{ if (! host_ip_no)
     host_ip_no = gethostbyname(gethostname())[1][0];
  
  if (! database)
  { database = Sql.sql(query(DBURL));

    if (database)
    { database_status = "connected (" + database->host_info() + ")";
      update();
    }
    else
      database_status = "unavailable.";
  }

  if (database &&
      last_update_time + 86400 < time())
  { // If the database is available, and a zonemaster file
    // update hasn't been done in 24 hours, schedule one.

    update();
  }
}

