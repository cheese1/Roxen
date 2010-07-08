#!bin/pike -m lib/pike/master.pike

/* buildenv.pike -- build an environment setup file for Roxen.
 *
 *    This script tries to build an environment setup file for
 *    Roxen, making sure Roxen has LD_LIBRARY_PATH and other
 *    essential variables set, to keep dynamic libraries and
 *    various other external stuff happy.
 */
 
string cvs_version = "$Id: buildenv.pike,v 1.11 2010/07/08 15:13:16 grubba Exp $";

class Environment
{
  protected string filename;
  protected mapping(string:array(string)) env, oldenv;

  protected void read()
  {
    string var, def;
    multiset(string) exports = (<>);
    Stdio.File f;
    env = ([]);
    oldenv = ([]);
    if (catch (f = Stdio.File(filename, "r")))
          return;

    foreach(f->read()/"\n", string line)
      if (sscanf(line-"\r", "%[A-Za-z0-9_]=%s", var, def)==2)
      {
	string pre, post, sep = ":";

	// Get rid of quotes.
	if (has_prefix(def, "\"") && has_suffix(def, "\"")) {
	  def = def[1..sizeof(def)-2];
	}

	/* The line is on one of the following formats:
	 *
	 * var=DEF				==> DEF
	 * var=${var}${var:+SEP}POST		==> SEP, POST
	 * var=PRE${var:+SEP}${var}		==> PRE, SEP
	 * var=PRE${var:+SEP}${var}SEPPOST	==> PRE, SEP, POST
	 */

	if(2==sscanf(def, "%s${"+var+"}%s", pre, post) ||
	   2==sscanf(def, "%s$"+var+"%s", pre, post))
	{
	  if (pre=="")
	    pre = 0;
	  else if (pre[-1]==':')
	    pre = pre[..sizeof(pre)-2];
	  else
	    sscanf(pre, "%s${" + var + ":+%s}", pre, sep);
	  if (post=="")
	    post = 0;
	  else if (has_prefix(post, sep))
	    post = post[sizeof(sep)..];
	  else 
	    sscanf(post, "${" + var + ":+%s}%s", sep, post);
	  env[var] = ({ pre, 0, post, sep });
	}
	else
	  env[var] = ({ 0, def, 0, ":" });

	werror("Read definition for %s: %O\n"
	       "%O\n",
	       var, line, env[var]);
      }
      else if (sscanf(line, "export %s", var))
	foreach((replace(var, ({"\t","\r"}),({" "," "}))/" ")-({""}), string v)
	  exports[v] = 1;
    foreach(indices(env), string e)
      if (!exports[e])
	m_delete(env, e);
    oldenv = copy_value(env);
  }

  protected void write()
  {
    Stdio.File f = Stdio.File(filename, "cwt");
    if (!f)
    {
      error("Failed to write "+filename+"\n");
      return;
    }
    f->write("# This file is automatically generated by the buildenv.pike\n");
    f->write("# script. Generated on " + replace(ctime(time()),"\n","") + ".\n");
    f->write("#\n# Automatically generated. Please edit environment2 instead.\n");
    foreach(sort(indices(env)), string var)
    {
      array(string) v = env[var];
      if (v && (v[0]||v[1]||v[2]))
      {
	f->write(var+"=\"");
	if(v[1])
	  f->write((v[0]? v[0]+v[3]:"")+v[1]+(v[2]? v[3]+v[2]:""));
	else if (!v[0])
	  // Append only
	  f->write("${"+var+"}${"+var+":+" + v[3] + "}"+v[2]);
	else if (!v[2])
	  // Prepend only
	  f->write(v[0]+"${"+var+":+" + v[3] + "}${"+var+"}");
	else
	  // Prepend and append
	  f->write(v[0]+"${"+var+":+" + v[3] + "}${"+var+"}"+v[3]+v[2]);
	f->write("\"\nexport "+var+"\n");
      }
    }
    f->close();
  }

  protected int changed()
  {
    return !equal(env, oldenv);
  }

  void set_separator(string var, string sep)
  {
    array(string) v = env[var];
    if (!v)
      v = env[var] = ({ 0, 0, 0, ":" });
    v[3] = sep;
  }

  void append(string var, string val)
  {
    array(string) v = env[var];
    if (!v)
      v = env[var] = ({ 0, 0, 0, ":" });
    foreach(val/v[3], string comp)
      if ((!v[2]) || search(v[2]/v[3], comp)<0)
	v[2] = (v[2]? v[2]+v[3]:"")+comp;
  }

  void prepend(string var, string val)
  {
    array(string) v = env[var];
    if (!v)
      v = env[var] = ({ 0, 0, 0, ":" });
    foreach(val/v[3], string comp)
      if ((!v[0]) || search(v[0]/v[3], comp)<0)
	v[0] = comp+(v[0]? v[3]+v[0]:"");
  }

  void set(string var, string val)
  {
    array(string) v = env[var];
    if (!v)
      v = env[var] = ({ 0, 0, 0, ":" });
    // Compat with old scripts.
    if (has_prefix(val, "\"") && has_suffix(val, "\""))
      val = val[1..sizeof(val)-2];
    v[1] = val;
  }

  void remove(string var)
  {
    m_delete(env, var);
  }

  string get(string var)
  {
    array(string) v = env[var];
    return v && (v[..2]-({0}))*v[3];
  }

  string get_separator(string var)
  {
    array(string) v = env[var];
    return v && v[3];
  }

  int finalize()
  {
    if (!changed())
      return 0;
    write();
    return 1;
  }

  void create(string fn)
  {
    filename = fn;
    read();
  }

}

void config_env(object(Environment) env)
{
  string dir = "etc/env.d";
  program p;
  object eo;

  foreach(glob("*.pike", get_dir(dir)||({})), string e)
  { string name = (e/".")[0];
    if (!catch (p = compile_file(dir+"/"+e)))
    { if (eo = p())
        eo->run(env);
      else
        write("   Skipping %O.\n", name);
    }
    else
        write("   Test script %O failed to compile.\n", name);
  }
}

void main(int argc, array argv)
{
  string localdir = getenv("LOCALDIR") || combine_path(getcwd(), "../local");

  write("   Setting up environment in %s.\n", localdir);

  if (!Stdio.is_dir(localdir))
  { if (!Stdio.is_dir("bin") || !Stdio.is_dir("modules"))
    { write("   "+argv[0]+": "
	    "should be run in the Roxen 'server' directory.\n");
      exit(1);
    }
    if (!mkdir(localdir, 0775))
    {
      write("   Failed to create %s!\n", localdir);
      exit(1);
    }
  }

  Environment envobj = Environment(combine_path(localdir, "environment"));

  config_env(envobj);
  if (envobj->finalize())
  {
    write("   Environment updated.\n\n");
  }
  else
  {
    write("   Environment didn't need updating.\n\n");
  }
}


