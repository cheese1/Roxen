// Symbolic DB handling. 
//
// $Id: dbs.pike,v 1.7 2001/01/14 06:31:03 per Exp $
//! @module DBManager
//! Manages database aliases and permissions

constant NONE  = 0;
//! No permissions. Used in @[set_permission] and @[get_permission_map]
constant READ  = 1;
//! Read permission. Used in @[set_permission] and @[get_permission_map]
constant WRITE = 2;
//! Write permission. Used in @[set_permission] and @[get_permission_map]


private
{
  Sql.Sql db = connect_to_my_mysql( 0, "roxen" );
  function(string,mixed...:array(mapping(string:string))) query=db->query;

  string short( string n )
  {
    return lower_case(sprintf("%s%4x", n[..6],(hash( n )&65535) ));
  }

  void ensure_has_users( Sql.Sql db, Configuration c )
  {
    array q = db->query( "SELECT User FROM user WHERE User=%s",
                         short(c->name)+"_rw" );
    if( !sizeof( q ) )
    {
      db->query( "INSERT INTO user (Host,User,Password) "
                 "VALUES ('localhost',%s,'')",
                 short(c->name)+"_rw" ); 
      db->query( "INSERT INTO user (Host,User,Password) "
                 "VALUES ('localhost',%s,'')",
                 short(c->name)+"_ro" ); 
    }
  }

  void set_user_permissions( Configuration c, string name, int level )
  {
    Sql.Sql db = connect_to_my_mysql( 0, "mysql" );

    ensure_has_users( db, c );

    db->query("DELETE FROM db WHERE User LIKE '"+
              short(c->name)+"%%' AND Db=%s", name );

    if( level > 0 )
    {
      db->query("INSERT INTO db (Host,Db,User,Select_priv) "
                "VALUES ('localhost',%s,%s,'Y')",
                name, short(c->name)+"_ro");
      if( level > 1 )
        db->query("INSERT INTO db VALUES ('localhost',%s,%s,"
                  "'Y','Y','Y','Y','Y','Y','N','Y','Y','Y')",
                  name, short(c->name)+"_rw");
      else 
        db->query("INSERT INTO db  (Host,Db,User,Select_priv) "
                  "VALUES ('localhost',%s,%s,'Y')",
                  name, short(c->name)+"_rw");
    }
    db->query( "FLUSH PRIVILEGES" );
  }


  class ROWrapper( static Sql.Sql sql )
  {
    static int pe;
    static array(mapping(string:mixed)) query( string query, mixed ... args )
    {
      if( has_prefix( lower_case(query), "select" ) ||
          has_prefix( lower_case(query), "show" ) ||
          has_prefix( lower_case(query), "describe" ))
        return sql->query( query, @args );
      pe = 1;
      throw( ({ "Permission denied\n", backtrace()}) );
    }
    static object big_query( string query, mixed ... args )
    {
      if( has_prefix( lower_case(query), "select" ) ||
          has_prefix( lower_case(query), "show" ) ||
          has_prefix( lower_case(query), "describe" ))
        return sql->big_query( query, @args );
      pe = 1;
      throw( ({ "Permission denied\n", backtrace()}) );
    }
    static string error()
    {
      if( pe )
      {
        pe = 0;
        return "Permission denied";
      }
      return sql->error();
    }

    static string host_info()
    {
      return sql->host_info()+" (read only)";
    }

    static mixed `[]( string i )
    {
      switch( i )
      {
       case "query": return query;
       case "big_query": return big_query;
       case "host_info": return host_info;
       case "error": return error;
       default:
         return sql[i];
      }
    }
    static mixed `->( string i )
    {
      return `[](i);
    }
  }
  

  mapping (string:Thread.Local) sql_cache = ([]);
  Sql.Sql sql_cache_get(string what)
  {
    if(sql_cache[what] && sql_cache[what]->get())
      return sql_cache[what]->get();
    if(!sql_cache[what])
      sql_cache[what] =  Thread.Local();
    sql_cache[what]->set( Sql.Sql( what ) );
    return sql_cache[what]->get();
  }

  Sql.Sql low_get( string user, string db )
  {
    array(mapping(string:mixed)) d =
                query("SELECT path,local FROM dbs WHERE name=%s", db );
    if( !sizeof( d ) )
      return 0;
    if( (int)d[0]["local"] )
      return connect_to_my_mysql( user, db );

    // Otherwise it's a tad more complex...  
    if( user[strlen(user)-2..] == "ro" )
      // Avoid type-warnings and errors.
      //
      // The ROWrapper object really has all member functions Sql.Sql
      // has, but they are hidden behind an overloaded index operator.
      // Thus, we have to fool the typechecker.
      return [object(Sql.Sql)](object)ROWrapper( sql_cache_get( d[0]->path ) );
    return sql_cache_get( d[0]->path );
  }
};

array(string) list( void|Configuration c )
//! List all database aliases.
//!
//! If @[c] is specified, only databases that the given configuration can
//! access will be visible.
{
  array(mapping(string:string)) res;
  if( c )
    return  query( "SELECT "
                   " dbs.name AS name "
                   "FROM "
                   " dbs,db_permissions "
                   "WHERE"
                   " dbs.name=db_permissions.db"
                   " AND db_permissions.config=%s"
                   " AND db_permissions.permission!='none'",
                   c->name)->name;
  return query( "SELECT name from dbs" )->name;
}

mapping(string:mapping(string:int)) get_permission_map( )
//! Get a list of all permissions for all databases.
//! Return format:
//! ([
//!  "dbname":([ "configname":level, ... ])
//!   ...
//!  ])
//!
//! Level is as for @[set_permission()].
{
  mapping(string:mapping(string:int)) res = ([]);

  foreach( query("SELECT name FROM dbs"), mapping(string:string) n )
  {
    mixed m = query( "SELECT * FROM db_permissions WHERE db=%s",
                     n->name );
    if( sizeof( m ) )
      foreach( m, m )
      {
        if( !res[m->db] )res[m->db] = ([]);
        switch( m->permission )
        {
         case "none":    res[m->db][m->config] = NONE; break;
         case "read":    res[m->db][m->config] = READ; break;
         case "write":   res[m->db][m->config] = WRITE; break;
        }
      }
    else
      res[n->name] = ([]);
  }
  foreach( indices(res), string q )
    foreach( roxen->configurations, Configuration c )
      if( zero_type( res[q][c->name] ) )
        res[q][c->name] = 0;
  return res;
}

mapping db_stats( string name )
//! Return statistics for the specified database (such as the number
//! of tables and their total size). If the database is not an
//! internal database, or the database does not exist, 0 is returned
{
//   array(mapping(string:mixed)) d =
//            query("SELECT path,local FROM dbs WHERE name=%s", db );
//   if( !(sizeof( d ) && (int)d[0]["local"] ) )
//     return 0;
  array d;
  Sql.Sql db = get( name );
  if( catch( d = db->query( "SHOW TABLE STATUS" ) ) )
    return 0;
  mapping res = ([]);
  foreach( d, mapping r )
  {
    res->size += (int)r->Data_length+(int)r->Index_length;
    res->tables++;
    res->rows += (int)r->Rows;
  }
  return res;
}


int is_internal( string name )
//! Return true if the DB @[name] is an internal database
{
  array(mapping(string:mixed)) d =
           query("SELECT path,local FROM dbs WHERE name=%s", name );
  if( !sizeof( d ) ) return 0;
  return (int)d[0]["local"];
}

string db_url( string name )
//! Return true if the DB @[name] is an internal database
{
  array(mapping(string:mixed)) d =
           query("SELECT path,local FROM dbs WHERE name=%s", name );
  if( !sizeof( d ) ) return 0;
  return d[0]->path;
}

Sql.Sql get( string name, void|Configuration c, int|void ro )
//! Get the database @[name]. If the configuration @[c] is specified,
//! only return the database if the configuration has at least read
//! access.
{
  array(mapping(string:mixed)) res;
  if( c )
  {
    res = query( "SELECT permission FROM db_permissions "
                 "WHERE db=%s AND config=%s AND permission!='none'",
                 name,c->name);
    if( sizeof( res ) )
      return low_get( short(c->name) +
                      ((ro || res[0]->permission!="write")?"_ro":"_rw"),
                      name );
    return 0;
  }
  return low_get( (ro?"ro":"rw"), name );
}

void drop_db( string name )
//! Drop the database @[name]. If the database is internal, the actual
//! tables will be deleted as well.
{
  array q = query( "SELECT name,local FROM dbs WHERE name=%s", name );
  if( sizeof( q ) && (int)q[0]["local"] )
    query( "DROP DATABASE "+name );
  query( "DELETE FROM dbs WHERE name=%s", name );
  query( "DELETE FROM permissions WHERE db=%s", name );
}


void create_db( string name, string path, int is_internal )
//! Create a new symbolic database alias.
//!
//! If @[is_internal] is specified, the database will be automatically
//! created if it does not exist, and the @[path] argument is ignored.
//!
//! If the database @[name] already exists, an error will be thrown
{
  if( get( name ) )
    error("The database "+name+" already exists\n");
  query( "INSERT INTO dbs values (%s,%s,%s)",
         name, (is_internal?name:path), (is_internal?"1":"0") );
  if( is_internal )
    catch(query( "CREATE DATABASE "+name));
}


int set_permission( string name, Configuration c, int level )
//! Set the permission for the configuration @[c] on the database
//! @[name] to @[level].
//!
//! Levels:
//!  DBManager.NONE:  No access
//!  DBManager.READ:  Read access
//!  DBManager.WRITE: Write access
//!
//!  Please note that for non-local databases, it's not really
//!  possible to differentiate between read and write permissions,
//!  roxen does try to do that anyway by checking the requests and
//!  disallowing anything but 'select' and 'show' from read only
//!  databases. Please note that this is not really all that secure.
//!
//!  From local (in the mysql used by Roxen) databases, the
//!  permissions are enforced by using different users, and should be
//!  secure as long as the permission system in mysql is not modified
//!  directly by the administrator.
//!
//!  This function returns 0 if it fails. The only reason for it to
//!  fail is if there is no database with the specified @[name].
{
  array(mapping(string:mixed)) d =
           query("SELECT path,local FROM dbs WHERE name=%s", name );

  if( !sizeof( d ) )
      return 0;

  query( "DELETE FROM db_permissions WHERE db=%s AND config=%s",
         name,c->name );
  query( "INSERT INTO db_permissions VALUES (%s,%s,%s)",
         name,c->name,(level?level==2?"write":"read":"none") );
  
  if( (int)d[0]["local"] )
  {
    set_user_permissions( c, name, level );
  }    
}

static void create()
{
  multiset q = (multiset)query( "SHOW TABLES" )->Tables_in_roxen;
  if( !q->dbs )
  {
    query( #"
CREATE TABLE dbs (
 name VARCHAR(20) NOT NULL PRIMARY KEY,
 path VARCHAR(100) NOT NULL, 
 local INT UNSIGNED NOT NULL )
 " );
    query( "INSERT INTO dbs values ('mysql', 'mysql', 1)" ); 
    query( "INSERT INTO dbs values ('roxen', 'roxen', 1)" ); 
    query( "INSERT INTO dbs values ('cache', 'cache', 1)" );
  }
  
  if( !q->db_permissions )
    query(#"
CREATE TABLE db_permissions (
 db VARCHAR(20) NOT NULL, 
 config VARCHAR(80) NOT NULL, 
 permission ENUM ('none','read','write') NOT NULL,
 INDEX db_conf (db,config))
" );
}
