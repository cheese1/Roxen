/* Roxen FTP protocol.
 *
 * $Id: ftp.pike,v 1.94 1998/05/08 00:36:56 grubba Exp $
 *
 * Written by:
 *	Pontus Hagland <law@lysator.liu.se>,
 *	David Hedbor <neotron@idonex.se>,
 *	Henrik Grubbström <grubba@idonex.se> and
 *	Marcus Comstedt <marcus@idonex.se>
 *
 * Some of the features: 
 *
 *	* All files are parsed the same way as if they were fetched via WWW.
 *
 *	* If someone logs in with a non-anonymous name, normal
 *	authentification is done. This means that you for example can
 *	use .htaccess files to limit access to different directories.
 *
 *	* You can have 'user ftp directories'. Just add a user database
 *	and a user filesystem. Notice that _normal_ non-anonymous ftp
 *	should not be used, due to security reasons.
 */

/* TODO
 *
 * ABOR		Abort transfer in progress.
 */

/*
 * Relevant RFC's:
 *
 * RFC 764	TELNET PROTOCOL SPECIFICATION
 * RFC 959	FILE TRANSFER PROTOCOL (FTP)
 * RFC 1123	Requirements for Internet Hosts -- Application and Support
 *
 * More or less obsolete RFC's:
 *
 * RFC 542	File Transfer Protocol for the ARPA Network
 * RFC 561	Standardizing Network Mail Headers
 * RFC 607	Comments on the File Transfer Protocol
 * RFC 614	Response to RFC 607, "Comments on the File Transfer Protocol"
 * RFC 640	Revised FTP Reply Codes
 * RFC 691	One More Try on the FTP
 * RFC 724	Proposed Official Standard for the
 *              Format of ARPA Network Messages
 * RFC 724	STANDARD FOR THE FORMAT OF
 *              ARPA NETWORK TEXT MESSAGES(1)
 * RFC 737	FTP Extension: XSEN
 * RFC 743	FTP extension: XRSQ/XRCP
 * RFC 751	SURVEY OF FTP MAIL AND MLFL
 * RFC 754	Out-of-Net Host Addresses for Mail
 * RFC 765	FILE TRANSFER PROTOCOL
 * RFC 775	DIRECTORY ORIENTED FTP COMMANDS
 */


inherit "http"; /* For the variables and such.. (Per) */ 
inherit "roxenlib";

#include <config.h>
#include <module.h>
#include <stat.h>

import Array;

#define perror	roxen_perror

// #define FTP_LS_DEBUG

#ifdef FTP_LS_DEBUG
#define DWRITE(X)	roxen_perror(X)
#else /* DEBUG */
#define DWRITE(X)
#endif /* DEBUG */

string controlport_addr, dataport_addr, cwd ="/";
int controlport_port, dataport_port;
object cmd_fd, pasv_port;
object curr_pipe=0;
int GRUK = random(predef::time(1));
function(object,mixed:void) pasv_callback;
mixed pasv_arg;
array(object) pasv_accepted;
array(string|int) session_auth = 0;
string username="", mode="A";
int restart_point = 0;
string oldcmd;

#undef QUERY
#define QUERY(X) roxen->variables->X[VAR_VALUE]
#define Query(X) conf->variables[X][VAR_VALUE]  /* Per */

#define DESCRIBE_MODE(m) (m=="I"?"BINARY":"ASCII")

/********************************/
/* private functions            */

void reply(string X)
{
  conf->hsent += strlen(X);
  cmd_fd->write(replace(X, "\n","\r\n"));
}

private string reply_enumerate(string s,string num)
{
   string *ss;
   ss=s/"\n";
   while (sizeof(ss)&&ss[-1]=="") ss=ss[0..sizeof(ss)-2];
   if (sizeof(ss)>1) 
      return num+"-"+(ss[0..sizeof(ss)-2]*("\n"+num+"-"))+
	     "\n"+num+" "+ss[-1]+"\n";
   return num+" "+ss[-1]+"\n";
}

private static multiset|int allowed_shells = 0;

private int check_shell(string shell)
{
  if (Query("shells") != "") {
    if (!allowed_shells) {
      object(Stdio.File) file = Stdio.File();

      if (file->open(Query("shells"), "r")) {
	allowed_shells = aggregate_multiset(@(map(file->read(0x7fffffff)/"\n",
						  lambda(string line) {
	  return((((line/"#")[0])/"" - ({" ", "\t"}))*"");
	} )-({""})));
#ifdef DEBUG
	perror(sprintf("ftp.pike: allowed_shells:%O\n", allowed_shells));
#endif /* DEBUG */
      } else {
	perror(sprintf("ftp.pike: Failed to open shell database (\"%s\")\n",
		       Query("shells")));
	return(0);
      }
    }
    return(allowed_shells[shell]);
  }
  return(1);
}

/********************************/
/* public methods               */

void end(string|void);

void disconnect()
{
  if(objectp(pipe) && pipe != Simulate.previous_object()) 
    destruct(pipe);
  cmd_fd = 0;
  if(pasv_port) {
    destruct(pasv_port);
    pasv_port = 0;
  }
  destruct(this_object());
}

void end(string|void s)
{
  if(objectp(cmd_fd))
  {
    if(s)
      cmd_fd->write(s);
    destruct(cmd_fd);
  }
  disconnect();
}

/* We got some data on a socket.
 * ================================================= */

void got_data(mixed fooid, string s);

mapping internal_error(array err)
{
  roxen->nwrite("Internal server error: " +
		  describe_backtrace(err) + "\n");
  cmd_fd->write(reply_enumerate("Internal server error: "+
			       describe_backtrace(err)+"\n"+
			       "Service not available, please try again","421"));
}

mapping(string:array) stat_cache = ([]);

array my_stat_file(string f, string|void d)
{
  if (d) {
    f = combine_path(d, f);
  }
  array st;
  if ((st = stat_cache[f]) && st[1]) {
    if (_time(1) - st[0] < 3600) {
      // Keep stats one hour.
      return(st[1]);
    }
  }
  stat_cache[f] = ({ _time(1), st = roxen->stat_file(f, this_object()) });
  return(st);
}

string name_from_uid(int uid)
{
  array(string) user = conf->auth_module &&
    conf->auth_module->user_from_uid(uid);
  return (user && user[0]) || (uid?((string)uid):"root");
}

constant decode_mode = ({
  ({ S_IRUSR, S_IRUSR, 1, "r" }),
  ({ S_IWUSR, S_IWUSR, 2, "w" }),
  ({ S_IXUSR|S_ISUID, S_IXUSR, 3, "x" }),
  ({ S_IXUSR|S_ISUID, S_ISUID, 3, "S" }),
  ({ S_IXUSR|S_ISUID, S_IXUSR|S_ISUID, 3, "s" }),
  ({ S_IRGRP, S_IRGRP, 4, "r" }),
  ({ S_IWGRP, S_IWGRP, 5, "w" }),
  ({ S_IXGRP|S_ISGID, S_IXGRP, 6, "x" }),
  ({ S_IXGRP|S_ISGID, S_ISGID, 6, "S" }),
  ({ S_IXGRP|S_ISGID, S_IXGRP|S_ISGID, 6, "s" }),
  ({ S_IROTH, S_IROTH, 7, "r" }),
  ({ S_IWOTH, S_IWOTH, 8, "w" }),
  ({ S_IXOTH|S_ISVTX, S_IXOTH, 9, "x" }),
  ({ S_IXOTH|S_ISVTX, S_ISVTX, 9, "T" }),
  ({ S_IXOTH|S_ISVTX, S_IXOTH|S_ISVTX, 9, "t" })
});

/********************************/
/* Flags for the simulated 'ls' */

#define LS_FLAG_A	1
#define LS_FLAG_a	2
#define LS_FLAG_C	4
#define LS_FLAG_d	8
#define LS_FLAG_F	16
#define LS_FLAG_f	32
#define LS_FLAG_G	64
#define LS_FLAG_l	128
#define LS_FLAG_n	256
#define LS_FLAG_r	512
#define LS_FLAG_R	1024
#define LS_FLAG_t	2048
#define LS_FLAG_U	4096

string file_ls(array (int) st, string file, int flags)
{
  DWRITE(sprintf("file_ls(\"%s\", %08x)\n", file, flags));
  int mode = st[0] & 007777;
  array(string) perm = "----------"/"";
  
  if (st[1] < -1) {
    perm[0] = "d";
  }
  
  foreach(decode_mode, array(string|int) info) {
    if ((mode & info[0]) == info[1]) {
      perm[info[2]] = info[3];
    }
  }
  
  string ct = ctime(st[-4]);
  if (flags & LS_FLAG_G) {
    // No group.
    return sprintf("%s   1 %-10s %12d %s %s %s\n", perm*"",
		   (string)((flags & LS_FLAG_n)?st[-2]:name_from_uid(st[-2])),
		   (st[1]<0? 512:st[1]), ct[4..9], ct[11..15], file);
  } else {
    return sprintf("%s   1 %-10s %-6d%12d %s %s %s\n", perm*"",
		   (string)((flags & LS_FLAG_n)?st[-2]:name_from_uid(st[-2])),
		   st[-1], (st[1]<0? 512:st[1]), ct[4..9], ct[11..15], file);
  }
}

class ls_program {

  constant decode_flags =
  ([
    "A":LS_FLAG_A,
    "a":(LS_FLAG_a|LS_FLAG_A),
    "C":LS_FLAG_C,
    "d":LS_FLAG_d,
    "F":LS_FLAG_F,
    "f":(LS_FLAG_a|LS_FLAG_A|LS_FLAG_U),
    "G":LS_FLAG_G,
    "l":LS_FLAG_l,
    "n":LS_FLAG_n,
    "o":(LS_FLAG_l|LS_FLAG_G),
    "r":LS_FLAG_r,
    "R":LS_FLAG_R,
    "t":LS_FLAG_t,
    "U":LS_FLAG_U
   ]);

  object id;

  // NOTE: base is modified destructably!
  array(string) my_combine_path_array(array(string) base, string part)
  {
    if ((part == ".") || (part == "")) {
      if ((part == "") && (!sizeof(base))) {
	return(({""}));
      } else {
	return(base);
      }
    } else if ((part == "..") && sizeof(base) &&
	       (base[-1] != "..") && (base[-1] != "")) {
      base[-1] = part;
      return(base);
    } else {
      return(base + ({ part }));
    }
  }

  string my_combine_path(string base, string part)
  {
    if ((sizeof(part) && (part[0] == '/')) ||
	(sizeof(base) && (base[0] == '/'))) {
      return(combine_path(base, part));
    }
    // Combine two relative paths.
    int i;
    array(string) arr = ((base/"/") + (part/"/")) - ({ ".", "" });
    foreach(arr, string part) {
      if ((part == "..") && i && (arr[i-1] != "..")) {
	i--;
      } else {
	arr[i++] = part;
      }
    }
    if (i) {
      return(arr[..i-1]*"/");
    } else {
      return("");
    }
  }

  string list_files(mapping(string:array(mixed)) _files, string dir, int flags)
  {
    DWRITE(sprintf("list_files(\"%s\", 0x%08x)\n", dir, flags));
    int i;
    array(string) file_order = indices(_files);

    if (!(flags & LS_FLAG_U)) {
      if (flags & LS_FLAG_t) {
	array(int) times = allocate(sizeof(file_order));
	for (i=0; i < sizeof(file_order); i++) {
	  array st = _files[file_order[i]];
	  if (st) {
	    times[i] = st[-4];
	  } else {
	    file_order[i] = 0;
	  }
	}
	sort(times, file_order);
	if (!(flags & LS_FLAG_r)) {
	  reverse(file_order);
	}
      } else {
	sort(file_order);
	if (flags & LS_FLAG_r) {
	  file_order = reverse(file_order);
	}
      }
      file_order -= ({ 0 });
    }
    string res = "";
    int total = 0;
    foreach(file_order, string short) {
      array st = _files[short];
      if (st) {
	if (flags & LS_FLAG_F) {
	  if (st[1] < 0) {
	    // directory
	    short += "/";
	  } else if (st[0] & 0111) {
	    // executable
	    short += "*";
	  }
	}
	if (flags & LS_FLAG_l) {
	  res += id->file_ls(st, short, flags);
	  if (st[1] < 0) {
	    total += 1;	// One block
	  } else {
	    total += (st[1]+1023)/1024;	// Blocks are 1KB.
	  }
	} else {
	  res += short + "\n";
	}
      }
    }
    if (flags & LS_FLAG_l) {
      res = sprintf("total %d\n", total) + res;
    } else if (flags & LS_FLAG_C) {
      res = sprintf("%-#79s\n", res);
    }
    return(res);
  }

  object(Stack.stack) dir_stack = Stack.stack();
  int name_directories;
  int flags;

  class list_stream {
    static private function read_callback;
    static private function close_callback;
    static private object(ADT.queue) data = ADT.queue();
    mixed nb_id;
    int sent;
    
    int query_fd() { return -1; }
    void write_out()
    {
      DWRITE("list_stream->write_out()\n");
      while (!data->is_empty()) {
	string block = data->get();
	if (block) {
	  DWRITE(sprintf("list_stream->write_out(): Sending \"%s\"\n",
			 block));
	  if (sizeof(block)) {
	    read_callback(nb_id, block);
	    if (this_object()) {
	      sent += sizeof(block);
	    } else {
	      DWRITE(sprintf("list_stream->write:out(): DESTRUCTED!\n"));
	    }
	  }
	} else {
	  DWRITE(sprintf("list_stream->write_out(): EOD\n"));
	  // End of data marker
	  call_out(close_callback, 0, nb_id);
	  return;
	}
      }
    }
    void write(string s)
    {
      DWRITE(sprintf("list_stream->write(\"%O\")\n", (string)s));
      // write 0 to mark end of stream.
      if (!s || sizeof(s)) {
        data->put(s && replace(s, "\n", "\r\n"));
	if (read_callback) {
	  write_out();
	}
      }
    }
    void set_nonblocking(function _read_cb,
			 function _write_cb,
			 function _close_cb)
    {
      read_callback = _read_cb;
      close_callback = _close_cb;
      if (!data->is_empty()) {
	call_out(write_out, 0);
      }
    }
    object id;
    void create(object _id)
    {
      DWRITE("list_stream()\n");
      id = _id;
    }
    void destroy()
    {
      DWRITE("list_stream() TERMINATING\n");
      catch { id->ls_session = 0; };
      roxen->log(([ "error": 200, "len": sent ]), id);
    }
    void close()
    {
      // _verify_internals();
      DWRITE("list_stream->close()\n");
      catch { id->ls_session = 0; };
      if (this_object()) {
	read_callback = 0;
	close_callback = 0;
	if (this_object()) {
	  // Paranoia.
	  catch { destruct(); };
	}
      }
    }
    void set_blocking() {}
  };

  object(list_stream) output;

  int|void do_assynch_dir_ls() 
  {
    DWRITE("do_assynch_dir_ls()\n");
    if (output) {
      if (dir_stack->ptr) {
	string short = dir_stack->pop();
	string long = combine_path(id->cwd, short);
	if ((!sizeof(long)) || (long[-1] != '/')) {
	  long += "/";
	}
	mapping(string:array(mixed)) _dir = id->conf->find_dir_stat(long, id);
	DWRITE(sprintf("do_assynch_dir_ls(): find_dir_stat(\"%s\") => %O\n",
		       long, _dir));
	if ((flags & LS_FLAG_a) &&
	    (long != "/")) {
	  if (_dir) {
	    _dir[".."] = roxen->stat_file(combine_path(long,"../"), id);
	  } else {
	    _dir = ([ "..":roxen->stat_file(combine_path(long,"../"), id) ]);
	  }
	}
	string s = "\n";
	if (_dir && sizeof(_dir)) {
	  if (!(flags & LS_FLAG_A)) {
	    foreach(indices(_dir), string f) {
	      if (sizeof(f) && (f[0] == '.')) {
		m_delete(_dir, f);
	      }
	    }
	  } else if (!(flags & LS_FLAG_a)) {
	    foreach(indices(_dir), string f) {
	      if ((f - ".") == "") {
		m_delete(_dir, f);
	      }
	    }
	  }
	  if (flags & LS_FLAG_R) {
	    foreach(indices(_dir), string f) {
	      if (!((<".","..">)[f])) {
		array(mixed) st = _dir[f];
		if (st && (st[1] < 0)) {
		  m_delete(_dir, f);
		  if (short[-1] != '/') {
		    f = short + "/" + f;
		  } else {
		    f = short + f;
		  }
		  _dir[f] = st;
		  name_directories=1;
		  dir_stack->push(f);
		}
	      }
	    }
	  }
	  if (sizeof(_dir)) {
	    s = list_files(_dir, combine_path(id->cwd, short)+"/", flags);
	  }
	} else {
	  DWRITE("do_assynch_dir_ls(): NO FILES!\n");
	}
	if (name_directories) {
	  s = "\n" + short + ":\n" + s;
	}
	if (s != "") {
	  output->write(s);
	}

	// Call me again.
#ifdef THREADS
	return 1;
#else
	call_out(do_assynch_dir_ls, 0);
#endif /* THREADS */
      } else {
	output->write(0);
      }
    }
  }

  void do_ls(mapping(string:mixed) args)
  {
    DWRITE("do_ls()\n");
    if (output) {
      foreach(indices(args), string short) {
	array st = id->my_stat_file(id->not_query =
				    combine_path(id->cwd, short));
	if (st && (st[1] < -1)) {
	  // Directory
	  if (!(flags & LS_FLAG_d)) {
	    dir_stack->push(short);
	    m_delete(args, short);
	  }
	} else if (!st || (st[1] == -1)) {
	  // Not found
	  output->write(short + " not found\n");
	  m_delete(args, short);
	}
      }

      string files = "";

      if (sizeof(args)) {
	foreach(indices(args), string s) {
	  args[s] = id->my_stat_file(combine_path(id->cwd, s));
	}
	output->write(files = list_files(args, id->cwd, flags));
      }

      if ((dir_stack->ptr > 1) || (sizeof(files))) {
	name_directories = 1;
      }

#ifdef THREADS
      // No need to do it asynchronously, we'd just tie up the backend.
      while(do_assynch_dir_ls())
	;
#else /* THREADS */
      call_out(do_assynch_dir_ls, 0);
#endif /* THREADS */
    }
  }

  array(string) glob_expand_command_line(string arg)
  {
    DWRITE(sprintf("glob_expand_command_line(\"%s\")\n", arg));
    array(string|array(string)) args = (replace(arg, "\t", " ")/" ") -
      ({ "" });
    int index;

    id->method="LIST";
    
    for(index = 0; index < sizeof(args); index++) {

      // Glob-expand args[index]

      array (int) st;
    
      if (replace(args[index], ({"*", "?"}), ({ "", "" })) != args[index]) {

	// Globs in the file-name.

	array(string|array(string)) matches = ({ ({ }) });
	multiset(string) paths; // Used to filter out duplicates.
	int i;
	foreach(my_combine_path("", args[index])/"/", string part) {
	  paths = (<>);
	  if (replace(part, ({"*", "?"}), ({ "", "" })) != part) {
	    // Got a glob.
	    array(array(string)) new_matches = ({});
	    foreach(matches, array(string) path) {
	      array(string) dir;
	      dir = roxen->find_dir(combine_path(id->cwd, path*"/")+"/", id);
	      if (dir && sizeof(dir)) {
		dir = glob(part, dir);
		if ((< '*', '?' >)[part[0]]) {
		  // Glob-expanding does not expand to files starting with '.'
		  dir = Array.filter(dir, lambda(string f) {
		    return (sizeof(f) && (f[0] != '.'));
		  });
		}
		foreach(sort(dir), string f) {
		  array(string) arr = my_combine_path_array(path, f);
		  string p = arr*"/";
		  if (!paths[p]) {
		    paths[p] = 1;
		    new_matches += ({ arr });
		  }
		}
	      }
	    }
	    matches = new_matches;
	  } else {
	    // No glob
	    // Just add the part. Modify matches in-place.
	    for(i=0; i<sizeof(matches); i++) {
	      matches[i] = my_combine_path_array(matches[i], part);
	      string path = matches[i]*"/";
	      if (paths[path]) {
		matches[i] = 0;
	      } else {
		paths[path] = 1;
	      }
	    }
	    matches -= ({ 0 });
	  }
	  if (!sizeof(matches)) {
	    break;
	  }
	}
	if (sizeof(matches)) {
	  // Array => string
	  for (i=0; i < sizeof(matches); i++) {
	    matches[i] *= "/";
	  }
	  // Filter out non-existing or forbiden files/directories
	  matches = Array.filter(matches, lambda(string short) {
	    id->not_query = combine_path(id->cwd, short);
	    return(id->my_stat_file(id->not_query));
	  });
	  if (sizeof(matches)) {
	    args[index] = matches;
	  }
	}
      }
      if (stringp(args[index])) {
	// No glob
	args[index] = ({ my_combine_path("", args[index]) });
      }
    }
    return(args * ({}));
  }

  void destroy()
  {
    DWRITE("ls_program() TERMINATED\n");
    if (output) {
      destruct(output);
    }
  }

  void create(string arg, object _id)
  {
    DWRITE(sprintf("ls_program(\"%s\")\n", arg));
    mixed err;
    err = catch {
      id = _id;

      array(string) args = glob_expand_command_line(arg);

      args = ({ "ls" }) + args;

      array options;

      if (err = catch {
        options = Getopt.find_all_options(args, ({
	  ({ "A", Getopt.NO_ARG, ({ "-A", "--almost-all" })}),
	  ({ "a", Getopt.NO_ARG, ({ "-a", "--all" })}),
	  ({ "C", Getopt.NO_ARG, "-C" }),
	  ({ "d", Getopt.NO_ARG, ({ "-d", "--directory" })}),
	  ({ "F", Getopt.NO_ARG, ({ "-F", "--classify" })}),
	  ({ "f", Getopt.NO_ARG, "-f" }),
	  ({ "G", Getopt.NO_ARG, ({ "-G", "--no-group" })}),
	  ({ "g", Getopt.NO_ARG, "-g" }),
	  ({ "L", Getopt.NO_ARG, ({ "-L", "--dereference" })}),
	  ({ "l", Getopt.NO_ARG, "-l" }),
	  ({ "n", Getopt.NO_ARG, ({ "-n", "--numeric-uid-gid" })}),
	  ({ "o", Getopt.NO_ARG, "-o" }),
	  ({ "r", Getopt.NO_ARG, ({ "-r", "--reverse" })}),
	  ({ "R", Getopt.NO_ARG, ({ "-R", "--recursive" })}),
	  ({ "t", Getopt.NO_ARG, "-t" }),
	  ({ "U", Getopt.NO_ARG, "-U" }),
        }), 1, 1);
      }) {
	id->reply(id->reply_enumerate(err[0], "550"));
	return;
      }

      foreach(options, array(mixed) option) {
	flags |= decode_flags[option[0]];
      }

      if (flags & LS_FLAG_d) {
	flags &= ~LS_FLAG_R;
      }
      if (flags & LS_FLAG_f) {
	flags &= ~LS_FLAG_l;
      }
      if (err = catch {
	args = Getopt.get_args(args, 1, 1)[1..];
      }) {
	id->reply(id->reply_enumerate(err[0], "550"));
	return;
      }
      
      if (!sizeof(args)) {
	args = ({ "./" });
      }

      output = list_stream(id);
      id->connect_and_send(([ "file":output ]));
      
      do_ls(mkmapping(args, args));
      return;
    };
    err = sprintf("ftp: builtin_ls: Internal error:\n%s\n",
		  describe_backtrace(err));
    report_error(err);
#ifdef MODULE_DEBUG
    id->reply(id->reply_enumerate(err, "550"));
#else
    id->reply("550 ftp: builtin_ls: Internal error\n");
#endif /* MODULE_DEBUG */
  }
};

void pasv_accept_callback(mixed id)
{
  if(pasv_port) {
    object fd = pasv_port->accept();
    if(fd) {
      // On a multihomed server host, the default data transfer port
      // (L-1) MUST be associated with the same local IP address as
      // the corresponding control connection to port L.
      // RFC 1123 4.1.2.12
      array(string) remote = (fd->query_address()||"? ?")/" ";
#ifdef FD_DEBUG
      mark_fd(fd->query_fd(),
	      "ftp communication: -> "+remote[0]+":"+remote[1]);
#endif
      if(pasv_callback) {
	pasv_callback(fd, pasv_arg);
	pasv_callback = 0;
      } else
	pasv_accepted += ({ fd });
    }
  }
}

void ftp_async_accept(function(object,mixed:void) callback, mixed arg)
{
  if(sizeof(pasv_accepted)) {
    callback(pasv_accepted[0], arg);
    pasv_accepted = pasv_accepted[1..];
  } else {
    pasv_callback = callback;
    pasv_arg = arg;
  }
}

void done_callback(object fd)
{
  if(fd)
  {
    if (fd->set_blocking) {
      fd->set_blocking();	// Force close() to flush any buffers.
    }
    fd->close();
    destruct(fd);
  }
  curr_pipe = 0;
  reply("226 Transfer complete.\n");
  cmd_fd->set_read_callback(got_data);
  cmd_fd->set_write_callback(lambda(){});
  cmd_fd->set_close_callback(end);
#ifdef FD_DEBUG
  mark_fd(cmd_fd->query_fd(), GRUK+" cmd channel not sending data");
#endif
}

void connected_to_send(object fd,mapping file)
{
  object pipe=roxen->pipe();

  if(!file->len)
    file->len = file->data?(stringp(file->data)?strlen(file->data):0):0;

  if(fd)
  {
    if (file->len) {
      reply(sprintf("150 Opening "+DESCRIBE_MODE(mode)+" data connection for %s "
		    "(%d bytes).\n", not_query, file->len));
    } else {
      reply(sprintf("150 Opening "+DESCRIBE_MODE(mode)+" mode data connection for %s\n",
		    not_query));
    }
  }
  else
  {
    reply("425 Can't build data connect: Connection refused.\n"); 
    return;
  }
  if(mode == "A")
  {
    if(objectp(file->file) && file->file->read)
    {
      // The list_stream object doesn't have a read method,
      // but converts to ASCII anyway, so we don't have to do
      // anything about it.
      if(!file->data) file->data="";
      file->data += file->file->read();
      file->file=0;
    }
    if (file->data) {
      file->data = replace(file->data, "\n", "\r\n");
    }
  }
  if(stringp(file->data))  pipe->write(file->data);
  if(file->file) {
    file->file->set_blocking();
    pipe->input(file->file);
  }

  curr_pipe = pipe;
  pipe->set_done_callback(done_callback, fd);
  pipe->output(fd);
}

inherit "socket";
void ftp_async_connect(function(object,mixed:void) fun, mixed arg)
{
  // More or less copied from socket.pike
  
  object(Stdio.File) f = Stdio.File();

  string|int local_addr = (cmd_fd->query_address(1)/" ")[0];

  object privs;
  if(controlport_port-1 < 1024)
    privs = Privs("FTP: Opening the data connection on " + local_addr +
			 ":" + (controlport_port-1) + ".");

  if(!f->open_socket(controlport_port-1, local_addr))
  {
    privs = 0;
#ifdef FTP_DEBUG
    perror("ftp: socket("+(controlport_port-1)+") failed. Trying with any port.\n");
#endif
    gc();
    if (!f->open_socket()) {
#ifdef FTP_DEBUG
      perror("ftp: socket() failed. Out of sockets?\n");
#endif
      fun(0, arg);
      destruct(f);
      return;
    }
  }
  privs = 0;

  f->set_id( ({ fun, ({ arg }), f }) );
  f->set_nonblocking(0, lambda(array args) {
#ifdef FTP_DEBUG
    perror("ftp: async_connect ok.\n");
#endif
    args[2]->set_id(0);
    args[0](args[2], @args[1]);
  }, lambda(array args) {
#ifdef FTP_DEBUG
    perror("ftp: connect_and_send failed\n");
#endif
    args[2]->set_id(0);
    destruct(args[2]);
    args[0](0, @args[1]);
  });

#ifdef FD_DEBUG
  mark_fd(f->query_fd(), "ftp communication: " + local_addr + ":" +
	  (controlport_port - 1) + " -> " +
	  dataport_addr + ":" + dataport_port);
#endif

  if(catch(f->connect(dataport_addr, dataport_port)))
  {
#ifdef FTP_DEBUG
    perror("ftp: Illegal internet address in connect in async comm.\n");
#endif
    fun(0, arg);
    destruct(f);
    return;
  }  
}

void connect_and_send(mapping file)
{
  if(pasv_port)
    ftp_async_accept(connected_to_send, file);
  else
    ftp_async_connect(connected_to_send, file);
}

class put_file_wrapper {

  inherit Stdio.File;

  static object id;
  static string response;
  static string gotdata;
  static int done, recvd;
  static function other_read_callback;
  static string mode;
  int bytes_received()
  {
    return recvd;
  }

  int close(string|void how)
  {
    if(how != "w" && !done) {
      id->reply(response);
      done = 1;
      id->file = 0;
      id->my_fd = 0;
    }
    return (how? ::close(how) : ::close());
  }

  string read(mixed ... args)
  {
    string r = ::read(@args);
    if(stringp(r) && (mode=="A")) r = replace(r, "\r\n", "\n");
    if(stringp(r))
      recvd += sizeof(r);
    return r;
  }

  static mixed my_read_callback(mixed id, string data)
  {
    if(stringp(data) && (mode=="A")) data = replace(data, "\r\n", "\n");
    if(stringp(data))
      recvd += sizeof(data);
    return other_read_callback(id, data);
  }

  void set_read_callback(function read_callback)
  {
    if(read_callback) {
      other_read_callback = read_callback;
      ::set_read_callback(my_read_callback);
    } else
      ::set_read_callback(read_callback);
  }

  void set_nonblocking(function ... args)
  {
    if(sizeof(args) && args[0]) {
      other_read_callback = args[0];
      ::set_nonblocking(my_read_callback, @args[1..]);
    } else
      ::set_nonblocking(@args);
  }

  int write(string data)
  {
    int n, code;
    string msg;
    gotdata += data;
    while((n=search(gotdata, "\n"))>=0) {
      if(3==sscanf(gotdata[..n], "HTTP/%*s %d %[^\r\n]", code, msg)
	 && code>199) {
	if(code < 300)
	  code = 200;
	else
	  code = 550;
	response = code + " " + msg + "\n";
      }
      gotdata = gotdata[n+1..];
    }
    if(mode=="A") gotdata = replace(gotdata, "\n", "\r\n");
    return strlen(data);
  }

  void create(object i, object f, string m)
  {
    id = i;
    mode=m;
    assign(f);
    response = "200 Stored.\n";
    gotdata = "";
    done = 0;
    recvd = 0;
  }

}

int open_file(string arg, int|void noport);

void connected_to_receive(object fd, string arg)
{
  if(fd)
  {
    reply(sprintf("150 Opening "+DESCRIBE_MODE(mode)+" mode data connection for %s.\n", arg));
  }
  else
  {
    reply("425 Can't build data connect: Connection refused.\n"); 
    return;
  }

  method = "PUT";
  my_fd = put_file_wrapper(this_object(), fd, mode);
  data = 0;
  misc->len = 0x7fffffff;

  if(open_file(arg)) {
    if(!(file->pipe)) {
      fd->close();
      switch(file->error) {
      case 401:
	reply("532 "+arg+": Need account for storing files.\n");
	break;
      case 501:
	reply("502 "+arg+": Command not implemented.\n");
	break;
      default:
	reply("550 "+arg+": Error opening file.\n");
      }
    }
  } else
    fd->close();
}

void connect_and_receive(string arg)
{
  if(pasv_port)
    ftp_async_accept(connected_to_receive, arg);
  else
    ftp_async_connect(connected_to_receive, arg);
}

int open_file(string arg, int|void noport)
{
  file=0;
  array (int) st;
  if(!noport)
    if(!dataport_addr || !dataport_port)
    {
      reply("425 Can't build data connect: Connection refused.\n"); 
      return 0;
    }
  
  if(arg[0] == '~')
    this_object()->not_query = combine_path("/", arg);
  else if(arg[0] == '/')
    this_object()->not_query = simplify_path(arg);
  else 
    this_object()->not_query = combine_path(cwd, arg);


  if(!file || (file->full_path != not_query))
  {
    if(file && file->file)
      destruct(file->file);
    file=0;
    foreach(conf->first_modules(), function funp)
      if(file = funp( this_object())) break;
    mixed err;
    if (!file) {
      st = my_stat_file(not_query);
      if(st && st[1] < 0) {
	reply("550 "+arg+": not a plain file.\n");
	file = 0;
	return 0;
      } else if(err = catch(file = roxen->get_file(this_object()))) {
	roxen_perror(sprintf("FTP: Error opening file\n%s\n",
			     describe_backtrace(err)));
	// Lots of paranoia.
	catch {
	  reply("550 "+arg+": Error, can't open file.\n");
	};
	catch {
	  file = 0;
	};
	return 0;
      }
    }
  }

  if(!file || (file->error && (file->error/100 != 2))) {
    switch(misc->error_code) {
    case 401:
    case 403:
      reply("550 "+arg+": Access denied.\n");
      break;
    case 405:
      reply("550 "+arg+": Method not allowed.\n");
      break;
    default:
      reply("550 "+arg+": No such file or directory.\n");
      break;
    }
    return 0;
  } else 
    file->full_path = not_query;
  
  if(!file->len)
  {
    if(file->data)   file->len = strlen(file->data);
    if(objectp(file->file))   file->len += file->file->stat()[1];
  }
  if(file->len > 0)
    conf->sent += file->len;
  if(file->error == 403)
  {
    reply("550 "+arg+": Permission denied by rule.\n");
    roxen->log(file, this_object());
    return 0;
  }
  
  if(file->error == 302 || file->error == 301)
  {
    reply("550 "+arg+": Redirect to "+file->Location+".\n");
    roxen->log(file, this_object());
    return 0;
  }

  return 1;
}

mapping(string:string) cmd_help = ([
  // Commands in the order from RFC 959

  "user":"<sp> username (Change user)",
  "pass":"<sp> password (Change password)",
  // "acct":"<sp> <account-information> (Account)",
  "cwd":"[ <sp> directory-name ] (Change working directory)",
  "cdup":"(Change to parent directory)",
  // "smnt":"<sp> <pathname> (Structure mount)",
  "quit":"(Terminate service)",
  "rein":"(Reinitialize)",
  "port":"<sp> b0, b1, b2, b3, b4 (Set port IP and number)",
  "pasv":"(Set server in passive mode)",
  "type":"<sp> [ A | E | I | L ] (Ascii, Ebcdic, Image, Local)",
  // "stru":"<sp> <structure-code> (File structure)",
  // "mode":"<sp> <mode-code> (Transfer mode)",
  "retr":"<sp> file-name (Retreive file)",
  "stor":"<sp> file-name (Store file)",
  // "stou":"(Store file with unique name)",
  // "appe":"<sp> <pathname> (Append file)",
  // "allo":"<sp> <decimal-integer> [<sp> R <sp> <decimal-integer>]"
  //        " (Allocate space for file)",
  "rest":"<sp> marker (Set restart marker)",
  // "rnfr":"<sp> <pathname> (Rename from)",
  // "rnto":"<sp> <pathname> (Rename to)",
  // "abor":"(Abort current transmission)",
  "dele":"<sp> file-name (Delete file)",
  // "rmd":"<sp> <pathname> (Remove directory)",
  // "mkd":"<sp> <pathname> (Make directory)",
  "pwd":"(Return current directory)",
  "list":"[ <sp> path-name ] (List directory)",
  "nlst":"[ <sp> path-name ] (List directory)",
  // "site":"<sp> <string> (Site parameters)",	// Has separate help
  "syst":"(Get type of operating system)",
  "stat":"<sp> path-name (Status for file)",
  "help":"[ <sp> <string> ] (Give help)",
  "noop":"(No operation)",

  // Old "Experimental commands"
  // Required by RFC 1123 4.1.3.1
  // "xmkd":"<sp> path-name (Make directory)",
  // "xrmd":"<sp> path-name (Remove directory)",
  "xpwd":"(Return current directory)",
  "xcwd":"[ <sp> directory-name ] (Change working directory)",
  "xcup":"(Change to parent directory)",

  // The following aren't in RFC 959
  "mdtm":"<sp> file-name (Modification time)",
  "size":"<sp> path-name (Size)",

  // These are in RFC 765 but not in RFC 959
  // "mail":"[<sp> <recipient name>] (Mail to user)",
  // "msnd":"[<sp> <recipient name>] (Mail send to terminal)",
  // "msom":"[<sp> <recipient name>] (Mail send to terminal or mailbox)",
  // "msam":"[<sp> <recipient name>] (Mail send to terminal and mailbox)",
  // "mrsq":"(Mail recipient scheme question)",
  // "mrcp":"(Mail recipient)",

  // This one is referenced in a lot of old RFCs
  // "mlfl":"(Mail file)",

  // These are in RFC 737
  // "xsen":"[<sp> <recipient name>] (Send to terminal)",
  // "xsem":"[<sp> <recipient name>] (Send, mail if can't)",
  // "xmas":"[<sp> <recipient name>] (Mail and send)",

  // These are in RFC 743
  // "xrsq":"[<SP> <scheme>] (Scheme selection)",
  // "xrcp":"<SP> <recipient name> (Recipient specification)",
]);

mapping(string:string) site_help = ([
  "prestate":"<sp> prestate"
]);

void timeout()
{
  // Recomended by RFC 1123 4.1.3.2

  reply("421 Timeout (3600 seconds): closing connection.\n");
  end();
}

object ls_session;

#if constant(thread_create)
object(Thread.Mutex) handler_lock = Thread.Mutex();
#endif /* constant(thread_create) */

string partial = "";

void handle_data(string s, mixed key)
{
  roxen_perror(sprintf("FTP: handle_data():%O\n", ({ s })));

  string cmdlin;
  time = _time(1);
  if (!objectp(cmd_fd)) {
    if (objectp(key))
      destruct(key);
    return;
  }
  array y;
  conf->received += strlen(s);
  remove_call_out(timeout);
  call_out(timeout, 3600);
  remoteaddr = (cmd_fd->query_address()/" ")[0];
  supports = (< "ftp", "images", "tables", >);
  prot = "FTP";
  method = "GET";

  // However, a server-FTP MUST be capable of
  // accepting and refusing Telnet negotiations (i.e., sending
  // DON'T/WON'T). RFC 1123 4.1.2.12
  // FIXME: Not supported yet.

  array a = s/"\377";
  if (sizeof(a) > 1) {
    int i = 1;
    string answer = "";
    while (i < sizeof(a)) {
      if (!sizeof(a[i])) {
	a[i] = "\377";	// Not likely...
	i++;
      } else {
	int j = i;
	switch(a[i][0]) {
	default:	// Unknown
	  // FIXME: Should probably have a warning here.
	  break;
	case 240:	// SE
	  break;
	case 241:	// NOP
	  break;
	case 242:	// Data Mark
	  break;
	case 243:	// Break
	  destruct();
	  break;
	case 244:	// Interrupt Process
	  break;
	case 245:	// Abort Output
	  break;
	case 246:	// Are You There
	  answer += "\377\361";	// NOP
	  break;
	case 247:	// Erase character
	  while (j--) {
	    if (sizeof(a[j])) {
	      a[j] = a[j][..sizeof(a[j])-2];
	      break;
	    }
	  }
	  break;
	case 248:	// Erase line
	  while (j--) {
	    int off;
	    if ((off = search(reverse(a[j]), "\n\r")) == -1) {
	      a[j] = "";
	    } else {
	      a[j] = a[j][..sizeof(a[j])-(off+1)];
	      break;
	    }
	  }
	  break;
	case 249:	// Go ahead
	  break;
	case 250:	// SB
	  break;
	case 251:	// WILL
	  answer += "\377\376"+a[i][1..1];	// DON'T xxx
	  a[i] = a[i][1..];	// Need to strip one extra char.
	  break;
	case 252:	// WON'T
	  break;
	case 253:	// DO
	  answer += "\377\374"+a[i][1..1];	// WON'T xxx
	  a[i] = a[i][1..];	// Need to strip one extra char.
	  break;
	case 254:	// DON'T
	  break;
	}
	a[i] = a[i][1..];
      }
    }
    
    if (sizeof(answer)) {
      reply(answer);
    }
    s = a*"";
  }

  // A single read() can contain multiple or partial commands
  // RFC 1123 4.1.2.10
  if (sizeof(partial)) {
    s = partial + s;
  }
  while (sscanf(s,"%s\r\n%s",cmdlin,s)==2)
  {
    string cmd,arg;


    // Lets hope the ftp-module doesn't store things in misc between
    // requests.
    // IT DOES!	/grubba
    mapping new_misc = ([]);
    foreach(({ "trace_enter", "trace_leave",
	       "uid", "gid", "gecos", "home", "shell" }), string s) {
      if (misc[s]) {
	new_misc[s] = misc[s];
      }
    }
    misc = new_misc;
    if (sscanf(cmdlin,"%s %s",cmd,arg)<2) 
      arg="",cmd=cmdlin;
    cmd=lower_case(cmd);
#ifdef DEBUG
    if(cmd == "pass")
      perror("recieved 'PASS xxxxxxxx' "+GRUK+"\n");
    else
      perror("recieved '"+cmdlin+"' "+GRUK+"\n");
#endif
    if (!conf->extra_statistics->ftp) {
      conf->extra_statistics->ftp = (["commands":([ cmd:1 ])]);
    } else if (!conf->extra_statistics->ftp->commands) {
      conf->extra_statistics->ftp->commands = ([ cmd:1 ]);
    } else {
      conf->extra_statistics->ftp->commands[cmd]++;
    }
    if (!((session_auth && session_auth[0]) ||
	  Query("anonymous_ftp") ||
	  (< "user", "pass", "rein" >)[cmd])) {
      reply("530 Please login with USER and PASS.\n");
      continue;
    }
    switch (cmd) {
    case "rein":
      reply("220 Server ready for new user.\n");
      session_auth = 0;
      rawauth = 0;
      auth = 0;
      cwd = "/";
      misc = ([]);
      stat_cache = roxen->query_var(conf->name + ":ftp:stat_cache") || ([]);
      break;
    case "user":
      session_auth = 0;
      auth = 0;
      stat_cache = roxen->query_var(conf->name + ":ftp:stat_cache") || ([]);
      cwd = "/";
      misc = ([]);
      if(!arg || arg == "ftp" || arg == "anonymous") {
	if (Query("anonymous_ftp")) {
	  reply("230 Anonymous ftp, at your service\n");
	} else {
	  reply("532 Anonymous ftp disabled\n");
	}
	rawauth = 0;
      } else {
	rawauth = username = arg;
	reply(sprintf("331 Password required for %s.\n", arg));
      }
      break;
      
    case "pass": 
      if(!rawauth) {
	if (Query("anonymous_ftp")) {
	  reply("230 Guest login ok, access restrictions apply.\n"); 
	} else {
	  reply("503 Login with USER first.\n");
	}
      } else {	
	method="LOGIN";
	y = ({ "Basic", username+":"+arg});
	realauth = y[1];
	// Use own stat cache.
	stat_cache = ([]);
	if(conf && conf->auth_module) {
	  y = conf->auth_module->auth( y, this_object() );

	  if (y[0] == 1) {
	    /* Authentification successfull */
	    if (!Query("named_ftp") || !check_shell(misc->shell)) {
	      reply("532 You are not allowed to use named-ftp. Try using anonymous\n");
	      /* roxen->(({ "error":403, "len":-1 ]), this_object()); */
	      break;
	    }
	  } else if (!Query("anonymous_ftp")) {
	    reply(sprintf("530 User %s access denied.\n", username));
	    break;
	  }
	} else if (!Query("anonymous_ftp")) {
	  reply("532 Need account to login.\n");
	  break;
	}
	session_auth = auth = y;
	if(auth[0] == 1) {
	  if (stringp(misc->home)) {
	    // Check if it is possible to cd to the users home-directory.
	    if ((misc->home == "") || (misc->home[-1] != '/')) {
	      misc->home += "/";
	    }
	    array(int) st = my_stat_file(misc->home);
	    if (st && (st[1] < 0)) {
	      cwd = misc->home;
	    }
	  }
	  reply("230 User "+username+" logged in.\n"); 
	} else
	  reply("230 Guest user "+username+" logged in.\n"); 
	/* roxen->log(([ "error": 202, "len":-1 ]), this_object()); */
      }
      break;

    case "quit": 
      reply("221 Bye! It was nice talking to you!\n"); 
      end(); 
      if (objectp(key))
	destruct(key);
      return;

    case "abor":
      if (curr_pipe) {
	destruct(curr_pipe);
	curr_pipe = 0;
	reply("426 Data transmission terminated.\n");
      }
      reply("226 'ABOR' Completed.\n");
      break;

    case "noop":
      reply("220 Nothing done ok\n");
      break;
    case "syst":
      reply("215 UNIX Type: L8: Roxen Challenger Information Server\n");
      break;
    case "pwd":
    case "xpwd":
      reply("257 \""+cwd+"\" is current directory.\n");
      break;
    case "cdup":
    case "xcup":
      arg = "..";
    case "cwd":
    case "xcwd":
      string ncwd, f;
      array (int) st;
      array (string) dir;

      if(!arg || !strlen(arg))
      {
	reply ("500 Syntax: CWD <new directory>\n");
	break;
      }
      if(arg[0] == '~')
	ncwd = combine_path("/", arg);
      else if(arg[0] == '/')
	ncwd = simplify_path(arg);
      else 
	ncwd = combine_path(cwd, arg);
      
      if ((ncwd == "") || (ncwd[-1] != '/')) {
	ncwd += "/";
      }

      // Restore auth-info
      auth = session_auth;

      st = my_stat_file(ncwd);

      if(!st) {
	reply("550 "+arg+": No such file or directory, or access denied.\n");
	break;
      }
      if(st[1] > -1) {
	reply("550 "+arg+": Not a directory.\n");
	break;
      }
      cwd = ncwd;
      not_query = cwd;
      if(dir = roxen->find_dir(cwd, this_object()))
      {
	string message = "";
	array (string) readme = ({});
	foreach(dir, f)
	{
	  if(f == ".message")
	    message = roxen->try_get_file(cwd + f, this_object()) ||"";
	  if(f[0..5] == "README")
	  {
	    if(st = my_stat_file(cwd + f))
	      readme += ({ sprintf("Please read the file %s\n  it was last "
				   "modified on %s - %d days ago\n", 
				   f, ctime(st[-4]) - "\n", 
				   (time - st[-4]) / 86400) });
	  }
	}
	if(sizeof(readme))
	  message += "\n" + readme * "\n";
	if(strlen(message))
	  reply(reply_enumerate(message+"\nCWD command successful.\n","250"));
	else 
	  reply("250 CWD command successful.\n");
	break;	  
      }
      reply("250 CWD command successful.\n");
      break;
      
    case "type":
      // I and L8 are required by RFC 1123 4.1.2.1

      array(string) a = arg/" ";
      switch(a[0]) {
      case "E":
	reply("504 EBCDIC mode not supported\n");
	break;
      case "L":
	if ((sizeof(a) > 1) && (a[1] != "8")) {
	  reply("504 Only 8bit LOCAL mode supported\n");
	  break;
	}
      case "I":
	mode="I";
	reply("200 Using BINARY mode for transferring files\n");
	break;
      case "A":
	mode="A";
	reply("200 Using ASCII mode for transferring files\n");
	break;
      default:
	reply("504 Only ASCII and BINARY modes supported\n");
	break;
      }
      break;

    case "port": 
      int a,b,c,d,e,f;
      if (sscanf(arg,"%d,%d,%d,%d,%d,%d",a,b,c,d,e,f)<6) 
	reply("501 I don't understand your parameters\n");
      else {
	dataport_addr=sprintf("%d.%d.%d.%d",a,b,c,d);
	dataport_port=e*256+f;
	if (pasv_port) {
	  destruct(pasv_port);
	}
	reply("200 PORT command ok ("+dataport_addr+
	      " port "+dataport_port+")\n");
      }
      break;
      
    case "nlst":
    case "list": 
      int flags = 0;
      mapping f;

      if (cmd == "list") {
	arg = "-l " + arg;
      }

      // Count this as a request.
      conf->requests++;

      // Restore auth-info
      auth = session_auth;

      if(!dataport_addr || !dataport_port)
      {
	reply("425 Can't build data connect: Connection refused.\n"); 
	break;
      }

      ls_session = ls_program(arg, this_object());

#if 0
      if(sscanf(arg, "-%s %s", args, arg)!=2)
      {
	if(!strlen(arg))
	  arg = cwd;
	else if(arg[0] == '-')
	{
	  args = arg;
	  arg = cwd;
	}
      }

      string file_arg;
      if(arg[0] == '~')
	file_arg = combine_path("/", arg);
      else if(arg[0] == '/')
	file_arg = simplify_path(arg);
      else 
	file_arg = combine_path(cwd, arg);

      if(args) {
	foreach((args/""), string flg) {
	  flags |= decode_flags[flg];
	}
      }

      // This is needed to get .htaccess to be read from the correct directory
      if (file_arg[-1] != '/') {
	array st = my_stat_file(file_arg);
	if (st && (st[1]<0)) {
	  file_arg+="/";
	}
      }

      not_query = file_arg;

      foreach(conf->first_modules(), function funp)
	if(f = funp( this_object())) break;
      if(!f)
      {
	f = ([ "data":list_file(arg, flags) ]);
	if(f->data == 0)
	  reply("550 "+arg+": No such file or directory.\n");
	else if(f->data == -1)
	  reply("550 "+arg+": Permission denied.\n");
	else
	  connect_and_send(f);
      } else {
	reply(reply_enumerate("Permission denied\n"+(f->data||""), "550"));
      }
#endif /* 0 */
      break;

    case "rest":
      if (!arg || !strlen(arg)) {
	reply("501 'REST': Missing argument\n");
	break;
      }
      restart_point = (int)arg;
      reply("350 REST OK\n");
      break;
	      
    case "retr": 
      // Count this as a request
      conf->requests++;

      string f;

      if(!arg || !strlen(arg))
      {
	reply("501 'RETR': Missing argument\n");
	break;
      }

      // Restore auth-info
      auth = session_auth;

      if(!open_file(arg))
	break;
      if (restart_point && (oldcmd == "rest")) {
	if (!(file->file && file->file->seek &&
	      (file->file->seek(restart_point) != -1))) {
	  reply("550 'RETR': Error restoring restart point\n");
	  break;
	}
      }
      restart_point = 0;
      connect_and_send(file);
      roxen->log(file, this_object());
      break;

    case "stat":
      // According to RFC 1123 4.1.3.3, this command can be sent during
      // a file-transfer.

      // Count this as a request
      conf->requests++;

      string|int dirlist;
      if(!arg || !strlen(arg))
      {
	reply("501 'STAT': Missing argument\n");
	break;
      }
      method="HEAD";
      reply("211-status of "+arg+":\n");

      // Restore auth-info
      auth = session_auth;

      not_query = arg = combine_path(cwd, arg);
      foreach(conf->first_modules(), function funp)
	if(f = funp( this_object())) break;
      if(f) dirlist = -1;
      else {
	array st = my_stat_file(arg);
	dirlist = st && file_ls(st, arg, 0);
      }
      
      if(!dirlist)
      {
	reply("Unknown file: "+arg+" doesn't exist.\n");
      } else if(dirlist == -1)
	reply("Access denied\n");
      else 
	reply(dirlist);
      reply("211 End of Status\n");
      break;
    case "mdtm":
      // Count this as a request
      conf->requests++;

      string fname;
      if(!arg || !strlen(arg))
      {
	reply("501 'MDTM': Missing argument\n");
	break;
      }
      method="HEAD";

      // Restore auth-info
      auth = session_auth;

      not_query = fname = combine_path(cwd, arg);
      foreach(conf->first_modules(), function funp)
	if(f = funp( this_object())) break;
      array st = my_stat_file(fname);
      if (st) {
	mapping m = localtime(st[3]);
	reply(sprintf("213 %04d%02d%02d%02d%02d%02d\n",
		      1900 + m->year, 1 + m->mon, m->mday,
		      m->hour, m->min, m->sec));
      } else {
	reply("550 "+fname+": No such file or directory.\n");
      }
      break;
    case "size":
      // Count this a request
      conf->requests++;

      if(!arg || !strlen(arg))
      {
	reply("501 'SIZE': Missing argument\n");
	break;
      }

      // Restore auth-info
      auth = session_auth;

      if(!open_file(arg))
	break;
      reply("213 "+ file->len +"\n");
      break;
    case "stor": // Store file..
      // Count this as a request
      conf->requests++;

      string f;
      if(!arg || !strlen(arg))
      {
	reply("501 'STOR': Missing argument\n");
	break;
      }

      // Restore auth-info
      auth = session_auth;

      connect_and_receive(arg);
      break;

    case "dele":
      // Count this as a request
      conf->requests++;

      if(!arg || !strlen(arg))
      {
	reply("501 'DELE': Missing argument\n");
	break;
      }

      // Restore auth-info
      auth = session_auth;

      method = "DELETE";
      data = 0;
      misc->len = 0;
      if(open_file(arg, 1))
	reply("254 Delete completed\n");

      break;

    case "pasv":
      // Required by RFC 1123 4.1.2.6

      if(pasv_port)
	destruct(pasv_port);
      pasv_port = Stdio.Port(0, pasv_accept_callback);
      int port=(int)((pasv_port->query_address()/" ")[1]);
      reply("227 Entering Passive Mode. "+replace(controlport_addr, ".", ",")+
	    ","+(port>>8)+","+(port&0xff)+"\n");
      break;

    case "help":
      if(!arg || !strlen(arg)) {
	reply(reply_enumerate(sprintf("The following commands are recognized:"
				      "\n%-#72;8s\n",
				      map(sort(indices(cmd_help)),
					  upper_case)*"\n"), "214"));
	break;
      }
      if(cmd_help[lower_case(arg)]) {
	reply(reply_enumerate("Syntax: "+upper_case(arg)+" "+
			      cmd_help[lower_case(arg)]+"\n", "214"));
	break;
      }
      if(2==sscanf(lower_case(arg), "site%*[ ]%s", arg)) {
	if(!strlen(arg)) {
	  reply(reply_enumerate(sprintf("The following SITE commands are "
					"recognized:\n%-#72;8s\n",
					map(sort(indices(site_help)),
					    upper_case)*"\n"), "214"));
	  break;
	}
	if(site_help[lower_case(arg)]) {
	  reply(reply_enumerate("Syntax: "+upper_case(arg)+" "+
				site_help[lower_case(arg)]+"\n", "214"));
	  break;
	}
      }
      reply("502 Unknown command "+upper_case(arg)+".\n");
      break;

      // Extended commands
    case "site":
      // Site specific commands are required to be part of the site command
      // by RFC 1123 4.1.2.8

      array(string) arr;

      if (!arg || !strlen(arg) || !sizeof(arr = (arg/" ")-({""}))) {
	reply(reply_enumerate("The following site dependant commands are available:\n"
			      "SITE PRESTATE <prestate>\tSet the prestate.\n",
			      "220"));
	break;
      }
      if (lower_case(arr[0]) != "prestate") {
	reply("504 Bad SITE command\n");
	break;
      }
      if (sizeof(arr) == 1) {
	reply("220 Prestate cleared\n");
	prestate = (<>);
	break;
      }
      
      prestate = aggregate_multiset(@((arr[1..]*" ")/","-({""})));
      reply("220 Prestate set\n");
      break;

    case "":
      /* The empty command, some stupid ftp-proxies send this. */
      break;

    case "mkd":
      method = "MKDIR";
      data = 0;
      misc->len = 0;
      if (open_file(arg, 1))
	reply("254 Mkdir successful\n");
      break;
      
    default:
      reply("502 command '"+ cmd +"' unimplemented.\n");
    }
    catch {
      oldcmd = cmd;
    };
  }

  catch {
    partial = s;
  };

  if (objectp(key))
    destruct(key);
}

void got_data(mixed fooid, string s)
{
  mixed key;
#if constant(thread_create)
  // NOTE: It's always the backend which locks, so we need to force
  // the lock to avoid a "Recursive mutex" error in case it is locked.
  key = handler_lock->lock(1);
#endif /* constant(thread_create) */
  // Support for threading. The key is needed to get the correct order.
  roxen->handle(handle_data, s, key);
}

int is_connection;

void destroy()
{
  if (is_connection) {
    conf->misc->ftp_users_now--;
  }
  if (ls_session) {
    destruct(ls_session);
  }
}

void create(object f, object c)
{
  if(f)
  {
    string fi;
    conf = c;
    stat_cache = roxen->query_var(conf->name + ":ftp:stat_cache");
    if (!stat_cache) {
      roxen->set_var(conf->name + ":ftp:stat_cache", stat_cache = ([]));
    }
    is_connection=1;
    conf->misc->ftp_users++;
    conf->misc->ftp_users_now++;
    cmd_fd = f;
    cmd_fd->set_id(0);

    cmd_fd->set_read_callback(got_data);
    cmd_fd->set_write_callback(lambda(){});
    cmd_fd->set_close_callback(end);

    sscanf(cmd_fd->query_address(17)||"", "%s %d",
	   controlport_addr, controlport_port);

    sscanf(cmd_fd->query_address()||"", "%s %d", dataport_addr, dataport_port);

    pasv_port = 0;
    pasv_callback = 0;
    pasv_accepted = ({ });

    not_query = "/welcome.msg";
    call_out(timeout, 3600);
    
#if 0
    if((fi = roxen->try_get_file("/welcome.msg", this_object()))||
       (fi = roxen->try_get_file("/.message", this_object())))
      reply(reply_enumerate(fi, "220"));
    else
#endif /* 0 */
      reply(reply_enumerate(Query("FTPWelcome"),"220"));
  }
}

