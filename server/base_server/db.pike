//#define USE_GDBM

/* $Id: db.pike,v 1.8 1997/02/14 03:50:13 per Exp $ */

private static inherit files.file;
private static mapping db;
private static string last;

#define DIR "dbm_dir.perdbm/"


private static void sync()
{
#ifdef DEBUG_DB
  perror("sync "+last+"\n");
#endif
  if(last)
  {
    perror("save ("+ last +")\n");
    if(!file::open(DIR+last,"wct"))
    {
      perror("FAILED TO OPEN FILE\n");
      error("Save of object not possible.\n");
    }
    file::write(encode_value(db));
    file::close();
  }
}

/* Public methods */



public int db_open(string f, int noread)
{
#ifdef DEBUG_DB
  perror("db_open "+f+"\n");
#endif
  if(!noread && (last != f))
  {
    int res;
    perror("restore ("+ f +")\n");
    last = f;
    res = file::open(DIR+f, "rc");
    if(!res)
    {
      mkdirhier(DIR+f);
      res = file::open(DIR+f, "rc");
      if(!res) return 0;
    }
    string s;
    if((s = file::read(0x7ffffff)) && strlen(s))
      db = decode_value(s);
    else
      db = ([ ]);
    file::close();
  } else
    db = ([ ]);
  return 1;
}


public void db_destroy()
{
#ifdef DEBUG_DB
  perror("db_destroy "+last+"\n");
#endif
  rm(DIR+last);
  last=0;
}

public void db_delete(string varname)
{
#ifdef DEBUG_DB
  perror("db_delete "+varname+" ("+last+")\n");
#endif
  m_delete(db, varname);
  sync();
}

public void db_set(string varname, mixed value)
{
#ifdef DEBUG_DB
  perror("db_set "+varname+" ("+last+")\n");
#endif
  db[varname] = value;
  sync();
}

public mixed db_get(string varname)
{
#ifdef DEBUG_DB
  perror("db_get "+varname+" ("+last+")\n");
#endif
  return db[varname];
}
