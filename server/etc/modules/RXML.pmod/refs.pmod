// Kludge for the circular module references.

void create()
{
  ._fix_module_ref ("PHtml", RXML.PHtml);
  ._fix_module_ref ("PExpr", RXML.PExpr);
  ._fix_module_ref (
    "empty_tagset",
    class {
      inherit RXML.TagSet;
      void create() {}
      void add_tag (RXML.Tag t)
	{RXML.parse_error ("Trying to change the empty tag set.\n");}
      void add_tags (array(RXML.Tag) ts)
	{RXML.parse_error ("Trying to change the empty tag set.\n");}
      void remove_tag (string|object(RXML.Tag) t)
	{RXML.parse_error ("Trying to change the empty tag set.\n");}
      mixed `->= (string var, mixed val)
	{RXML.parse_error ("Trying to change the empty tag set.\n");}
      mixed `-> (string var)
      {
	return (<"low_tags", "low_containers", "low_entities">)[var] ? ([]) : ::`-> (var);
      }
      mixed `[] (string var) {return `-> (var);}
      void changed()
	{RXML.parse_error ("Trying to change the empty tag set.\n");}
    }());
}
