class gdbm {
  inherit Gdbm.gdbm;
  object command_stream = files.file();

  // Command loop for forked copy..
  private static void command_loop(object fd)
  {
    int len;
    while(sscanf(fd->read(4), "%4c", len))
      catch(::store(@decode_value(fd->read(len))));
  }

  void store(string ... args)
  {
    string s=encode_value(args);
    if(command_stream->write(sprintf("%4c%s", strlen(s), s)) != (strlen(s)+4))
    {
      werror("PerGdbm: Error in store, write failed. Using fallback.\n");
      ::store( @args );
    }
  }

  void create(string ... args)
  {
    ::create(@args);
    object p =command_stream->pipe();
    command_stream->set_buffer(65536, "w");
    p->set_buffer(65536, "r");
    if(fork()) return;
    command_stream=0;
    catch(command_loop(p));
    perror("GDBM: Exit.\n");
    exit(0);
  }
}
