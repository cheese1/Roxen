#include <roxen.h>

import RoxenPatch;

//<locale-token project="admin_tasks"> LOCALE </locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("admin_tasks",X,Y)

constant action = "maintenance";

constant long_flags = ([ "restart" : "Need to restart server" ]);

string name= LOCALE(165, "Patch status");
string doc = LOCALE(166, "Show information about the available patches and "
			 "their status.");

Write_back wb = class Write_back
                {
		  private array(mapping(string:string)) all_messages = ({ });

		  void write_mess(string s) 
		  { 
		    s = replace(s, ([ 
			"ok.\n"   : "<b style='color: green'>ok.</b><br />",
			"Done!\n" : "<b style='color: green'>Done!</b><br />" ])
				);
		    all_messages += ({ (["message":s ]) }); 
		  }
		  
		  void write_error(string s) 
		  { 
		    all_messages += ({ 
		      ([ "error":"<b style='color: red'>" + s + "</b>" ]) 
		    }); 
		  }
		  
		  string get_messages() 
		  {
		    string res = "";
		    
		    foreach(all_messages->message, string s)
		    {
		      if(s)
			res += s;
		    }

		    return res;
		  }

		  string get_errors() 
		  {
		    string res = "";
		    foreach(all_messages->error, string s)
		    {
		      if(s)
			res += s;
		    }
		    return res;
		  }

		  void clear_all()
		  {
		    all_messages = ({ });
		  }

		  string get_all_messages()
		  {
		    string res = "";

		    foreach(all_messages, mapping m)
		    {
		      if (m->message)
			res += m->message;
		      else
			res += m->error;
		    }
		    
		    res = replace(res, "\n", "<br />");
		    return res;
		  }
                } ();

string list_patches(RequestID id, Patcher po, string which_list)
{
  string self_url = "?class=maintenance&action=patcher.pike";
  string res = "";

  array(mapping) list;
  int colspan;
  if (which_list == "installed")
  {
    list = po->file_list_installed();
    colspan = 5;
  }
  else if (which_list == "imported")
  {
    list = map(po->file_list_imported(), lambda(mapping m)
					 {
					   return ([ "metadata" : m ]);
					 }
	       );
    colspan = 4;
  }
  else
    // This should never happen.
    return 0;

  string table_bgcolor = "&usr.fade1;";
  if (list && sizeof(list))
  {
    foreach(list; int i; mapping item)
    {
      if (table_bgcolor == "&usr.content-bg;")
	table_bgcolor = "&usr.fade1;";
      else
	table_bgcolor = "&usr.content-bg;";

      string installed_date = "";
      if(which_list == "installed")
      {
	installed_date = sprintf("        <td><date strftime='%%c'"
				 " iso-time='%d-%02d-%02d %02d:%02d:%02d' />"
				 "</td>\n",
				 (item->year < 1900) ? 
				 item->installed->year + 1900 : 
				 item->installed->year,
				 item->installed->mon,
				 item->installed->mday,
				 item->installed->hour,
				 item->installed->min,
				 item->installed->sec
				 );
      }

      res += sprintf("      <tr valign='top' style='background-color: %s' >\n"
		     "        <td class='folded' id='%s_img'"
		     " style='background-color: %[0]s' "
		     " onmouseover='this.style.cursor=\"pointer\"'"
		     " onclick='expand(\"%[1]s\")' />&nbsp;</td>\n"
		     "        <td onclick='expand(\"%[1]s\");'"
		     " onmouseover='this.style.cursor=\"pointer\"'>%s</td>\n"
		     "        <td onclick='expand(\"%[1]s\");'"
		     " onmouseover='this.style.cursor=\"pointer\"'>%s</td>\n"
		     "%s"
		     "        <td><input type='checkbox' id='%[2]s'"
		     " name='%s' value='%[2]s' %s"
		     " onclick='toggle(\"%[2]s\", \"%[5]s\")' /></td>\n"
		     "      </tr>\n",
		     table_bgcolor,
		     replace(item->metadata->id, "-", ""),
		     item->metadata->id,
		     item->metadata->name,
		     installed_date,
		     (which_list == "imported") ? "install" : "uninstall",
		     (i > 0) ? "disabled=''" : " ");
	
      array md = ({
	//   	({ "Installed:"      , inst_date }),
	// 	({ "Installed by:"   , (obj->user) ? obj->user : "Unknown" }),
	({ "Description:"    , item->metadata->description }),
	({ "Originator:"     , item->metadata->originator  }) });
      

      string active_flags = "        <table class='module-sub-list'"
			    " width='50%'>\n";
      foreach(known_flags; string index; string long_reading)
      {
	active_flags += sprintf("          <tr><td>%s</td>"
				"<td style='width: 2em'><b>%s<b></td></tr>\n",
				long_reading + ":",
				(item->metadata->flags && 
				 item->metadata->flags[index]) ?
				"<b style='color: green'>Yes</b>" : 
				"<b>No</b>");
      }
      md += ({ ({ "Flags:", active_flags + "        </table>\n"}) });
 
      if (!item->metadata->platform)
      {
	md += ({
	  ({ "Platforms:", "All platforms" })
	});
      }
      else if (item->metadata->platform && 
	       sizeof(item->metadata->platform) == 1)
      {
	md += ({
	  ({ "Platform:", item->metadata->platform[0] })
	});
      }
      else
      {
	md += ({
	  ({ "Platforms:", 
	     sprintf("%{%s<br />\n%}",
		     item->metadata->platform) })
	});
      }
      
      if (item->metadata->version)
      {
	md += ({
	  ({ "Target version:", 
	     sprintf("%{%s<br />\n%}",
		     item->metadata->version) })
	});
      }
      else
      {
	md += ({
	  ({ "Target version:", "All versions" })
	});
      }
      
      if (item->metadata->depends)
      {
	md += ({
	  ({ "Dependencies:", 
	     sprintf("%{%s<br />\n%}",
		     item->metadata->depends) })
	});
      }
      else
      {
	md += ({
	  ({ "Dependencies:", "(none)" }),
	});
      }
      
      if (item->metadata->new && sizeof(item->metadata->new) == 1)
      {
	md += ({ 
	  ({ "New file:", sprintf("%s", 
				  item->metadata->new[0]->destination) }) 
	});
      }
      else if (item->metadata->new)
      {
	md += ({ 
	  ({ "New files:", sprintf("%{%s<br />\n%}", 
				   item->metadata->new->destination) })
	});
      }
      
      if (item->metadata->replace && sizeof(item->metadata->replace) == 1)
      {
	md += ({ 
	  ({ "Replaced file:",  
	     sprintf("%s", item->metadata->replace[0]->destination) })
	});
      }
      else if (item->metadata->replace)
      {
	md += ({ 
	  ({ "Replaced files:", 
	     sprintf("%{%s<br />\n%}", item->metadata->replace->destination) })
	});
      }
      
      if (item->metadata->delete && sizeof(item->metadata->delete) == 1)
      {
	md += ({ 
	  ({ "Deleted file:", 
	     sprintf("%s", item->metadata->delete[0]) })
	});
      }
      else if (item->metadata->delete)
      {
	md += ({
	  ({ "Deleted files:", 
	     sprintf("%{%s<br />\n%}", item->metadata->delete) })
	});
      }

      if (item->metadata->patch)
      {
	string patch_data = "";
	string patch_path = combine_path(po->get_installed_dir(),
					 item->metadata->id);
	foreach(item->metadata->patch, string patch_file)
	{
	  patch_data += Stdio.read_file(combine_path(patch_path,
						     patch_file));
	}
	
	array(string) patched_files_list = po->lsdiff(patch_data);
	if (sizeof(patched_files_list) == 1)
	{
	  md += ({
	    ({ "Patched file:",
	       sprintf("%s\n", patched_files_list[0]) })
	  });
	}
	else
	{
	  md += ({
	    ({ "Patched files:",
	       sprintf("%{%s<br />\n%}", patched_files_list) })
	  });
	  }
      }      

      res += sprintf("      <tr id='id%s' bgcolor='%s' "
		     " style='display: none'>\n"
		     "        <td>&nbsp;</td>\n"
		     "        <td colspan='%d'>\n"
 		     "          <table class='module-sub-list'"
  		     " cellspacing='0' cellpadding='3' border='0'>\n"
  		     "%{            <tr valign='top'>\n"
  		     "              <th align='right'>%s</th>\n"
  		     "              <td>\n%s</td>\n"
  		     "            </tr>\n%}"
  		     "          </table>\n"
		     "          <td>\n"
		     "        </td>\n"
		     "      </tr>\n",
		     replace(item->metadata->id, "-", ""),
		     table_bgcolor,
		     colspan - 2,
 		     md);
    }
  }
  else
  {
    res += sprintf("      <tr bgcolor='&usr.content-bg;'>\n"
		   "        <td colspan='%d'" 
		   " style='text-align:center;font-style:italic'>\n"
		   "          No patches found\n"
		   "        </td>\n"
		   "      </tr>\n",
		   colspan);
  }
  
  res += sprintf("      <tr>\n"
		 "        <td bgcolor='&usr.fade2;' colspan='%d'"
		 " align='right'>\n"
		 "          <submit-gbutton2"
		 " name='%s-button'>%s</submit-gbutton2>\n"
		 "        </td>\n"
		 "      </tr>\n",
		 colspan,
		 (which_list == "installed") ? "uninstall" : "install",
		 (which_list == "installed") ? "Uninstall" : "Install");

  return res; //+ sprintf("<td>&nbsp;</td>"
// 		       "<td>&nbsp;</td>"
// 		       "<td><pre>%O</pre></td>"
// 		       "<td>&nbsp;</td>"
// 		       "<td>&nbsp;</td>",
// 		       getenv("ROXEN_SERVER_DIR"));
}

mixed parse(RequestID id)
{
  // Init patch-object
  Patcher plib = Patcher(wb->write_mess,
  			 wb->write_error,
  			 getcwd(),
			 getenv("LOCALDIR"));
			 
  string res = #"
    <style type='text/css'>
      td.folded {
        width:      20px;
        height:     20px;
        background: url('&usr.unfold;') 50% 50% no-repeat;
      }

      td.unfolded {
        width:      20px;
        height:     20px;
        background: url('&usr.fold;') 50% 50% no-repeat;
      }

      span.folded {
        width:        20px;
        height:       20px;
        padding-left: 20px;    
        background:   url('&usr.unfold;') top left no-repeat;
      }

      span.unfolded {
        width:        20px;
        height:       20px;
        padding-left: 20px;    
        background:   url('&usr.fold;') top left no-repeat;
      }

      div#idlog {
        font-size:  smaller;
        background: &usr.obox-bodybg;;
        border:     2px solid &usr.obox-border;;        
      }
    </style>
    <script type='text/javascript'>
      // <![CDATA[
      function expand(element)
      {
        var blockToToggle = document.getElementById('id' + element);
        var pictureToToggle = document.getElementById(element + '_img');

        if (blockToToggle.style.display == 'none')
        {
          blockToToggle.style.display = '';
          pictureToToggle.className = 'unfolded';
        }
        else
        {
          blockToToggle.style.display = 'none';
          pictureToToggle.className = 'folded';
        }
      }

      function checkall(name)
      {
        var i;
        var reference = document.getElementById(name + '_all');
        var elements = document.getElementsByName(name)
        for (i = 0; i < elements.length; i++)
        {
          elements[i].checked = reference.checked;
          if (i > 1)
          {
            elements[i].disabled = !reference.checked;
          }
        }
      }

      function toggle(id, name)
      {
        var currentElement = document.getElementById(id);
        var allElements = document.getElementsByName(name)
        var currentNo = 0;
        if (allElements.length > 1)
        {
          
          for (var i = 1; i < allElements.length; i++)
          {
            if (currentNo && i > (currentNo + 1))
            {
              allElements[i].checked = false;
              allElements[i].disabled = true;
            }
            else if (allElements[i].id == id)
            {
              currentNo = i;

              if ((i+1) < allElements.length)
              {
                allElements[0].checked = false;
                allElements[i+1].checked = false;
                allElements[i+1].disabled = !currentElement.checked;
              }
              else
              {
                allElements[0].checked = currentElement.checked;
              }
            }
          }
        }
      }
      // ]]>
    </script>
";

  if (id->real_variables["OK.x"] &&
      id->real_variables["fixedfilename"] &&
      sizeof(id->real_variables["fixedfilename"][0]) &&
      id->real_variables["file"] &&
      sizeof(id->real_variables["file"][0]))
  {
    string temp_file = combine_path(plib->get_temp_dir(),
				    id->real_variables["fixedfilename"][0]);
      
    plib->write_file_to_disk(temp_file, id->real_variables["file"][0]);
    string patch_id = plib->import_file(temp_file);
    plib->clean_up(temp_file);

    if (patch_id)
      res += sprintf("<font size='+1' ><b>Importing %s</b></font><br /><br />\n"
		     "<p><b style='color: green'>"
		     "Patch successfully imported.</b></p>",
		     patch_id);
    else
      res += "<font size='+1' ><b>Importing &form.fixedfilename;</b></font>"
	     "<br /><br />\n"
	     "<p><b style='color: red'>Could not import patch.</b></p>";
    
    
    
    res += sprintf("<p><span id='log_img' class='folded'"
		   " onmouseover='this.style.cursor=\"pointer\"'"
		   " onclick='expand(\"log\")'>log</span>"
		   "<div style='display: none' id='idlog'>%s</div></p>\n"
		   "<br clear='all' /><br />\n"
		   "<link-gbutton href='?action=patcher.pike&"
		   "class=maintenance'>Back</link-gbutton>",
		   wb->get_all_messages());
    wb->clear_all();
  }
  else if (id->real_variables["uninstall-button.x"] &&
	   id->real_variables->uninstall &&
	   sizeof(id->real_variables->uninstall))
  {
    int successful_uninstalls;
    int no_of_patches;
    multiset flags = (< >);
    foreach(id->real_variables->uninstall, string patch)
    {
      if (patch != "on")
      {
	successful_uninstalls += plib->uninstall_patch(patch);
	no_of_patches++;
	PatchObject md = plib->get_metadata(patch);
	if (md && md->flags)
	  flags += md->flags;
      }
    }
    res += "<font size='+1' ><b>Uninstalling</b></font><br/><br/>\n"
	   "<h1>Done!</h1><br/>";

    if (no_of_patches == 1)
    {
      if (!successful_uninstalls)
	res += "<p>Failed to uninstall the patch. See the log below for "
	       "details</p>\n";
      else
	res += "<p>Patch uninstalled successfully. See the log below for "
	       "details</p>\n";
    }
    else
    {
      res += sprintf("<p>%d out of %d patches sucessfully uninstalled. "
		     "See the log below for details.</p>\n",
		     successful_uninstalls,
		     no_of_patches);
    }

    // Do we need to restart?
    if (flags->restart)
    {
      res += #"
<blockquote><br />
  The server needs to be restarted. Would you like to do  that now?<br/>
  <cf-perm perm='Restart'>
    <gbutton href='?what=restart&action=restart.pike&class=maintenance' 
             width=250 icon_src=&usr.err-2;> " + LOCALE(197,"Restart") + 
#"    </gbutton>
  </cf-perm>

  <cf-perm not perm='Restart'>
    <gbutton dim width=250 icon_src=&usr.err-2;> " + LOCALE(197,"Restart") + 
#"    </gbutton>
  </cf-perm>";
    }

    res += sprintf("<p><span id='log_img' class='folded'"
		   " onmouseover='this.style.cursor=\"pointer\"'"
		   " onclick='expand(\"log\")'>log</span>"
		   "<div style='display: none' id='idlog'>%s</div></p>\n"
		  "<link-gbutton href='?action=patcher.pike"
		  "&class=maintenance'>Back</link-gbutton>",
		  wb->get_all_messages());
    wb->clear_all();
  }
  else if (id->real_variables["install-button.x"] &&
	   id->real_variables->install &&
	   sizeof(id->real_variables->install))
  {
    int successful_installs;
    int no_of_patches;
    multiset flags = (< >);
    foreach(id->real_variables->install, string patch)
    {
      if (patch != "on")
      {
	successful_installs += 
	  plib->install_patch(patch, id->misc->config_user->real_name);
	no_of_patches++;
	PatchObject md = plib->get_metadata(patch);
	if (md && md->flags)
	  flags += md->flags;
      }
    }
    res += "<font size='+1' ><b>Installing</b></font><br/><br/>\n"
	   "<h1>Done!</h1><br/>";

    if (no_of_patches == 1)
    {
      if (!successful_installs)
	res += "<p>Failed to install the patch. See the log below for "
	       "details</p>\n";
      else
	res += "<p>Patch successfully installed. See the log below for "
	       "details</p>\n";
    }
    else
    {
      res += sprintf("<p>%d out of %d patches sucessfully installed. "
		     "See the log below for details.</p>\n",
		     successful_installs,
		     no_of_patches);
    }

    // Do we need to restart?
    if (flags->restart)
    {
      res += #"
<blockquote><br />
  The server needs to be restarted. 
  <cf-perm perm='Restart'>
    Would you like to do  that now?<br/>
    <gbutton href='?what=restart&action=restart.pike&class=maintenance' 
         >"/*    width='250' icon_src='&usr.err-2;'> "*/ + LOCALE(197,"Restart") + 
#"    </gbutton>
  </cf-perm>

  <cf-perm not perm='Restart'>
    <gbutton dim width=250 icon_src=&usr.err-2;> " + LOCALE(197,"Restart") + 
#"    </gbutton>
  </cf-perm>";
    }

    res += sprintf("<p><span id='log_img' class='folded'"
		   " onmouseover='this.style.cursor=\"pointer\"'"
		   " onclick='expand(\"log\")'>log</span>"
		   "<div style='display: none' id='idlog'>%s</div></p>\n"
		   "<link-gbutton href='?action=patcher.pike"
		   "&class=maintenance'>Back</link-gbutton>",
		  wb->get_all_messages());
    wb->clear_all();
  }
  else
  {
    // res += "<pre><insert variables='full' scope='form' /></pre>";
    res += #" 
    <font size='+1'><b>Import a new patch</b></font>
    <p>
      Select local file to upload: <br />
        <input type='file' name='file' size='40'/>
        <input type='hidden' name='fixedfilename' value='' />
        <submit-gbutton name='ok' width='75' align='center'
      onClick=\"this.form.fixedfilename.value=this.form.file.value.replace(/\\\\/g,'\\\\\\\\')\"><translate id=\"201\">OK</translate></submit-gbutton>
      <br /><br />
    </p>
    <font size='+1'><b>Imported Patches</b></font>
    <p>
      These are patches that are not currently installed; they are imported
      but not applied.
    </p>
    <p>
      Click on a Patch for more information.
    </p>
    <box-frame width='100%' iwidth='100%' bodybg='&usr.content-bg;'
	       box-frame='yes' padding='0'>\n
      <table class='module-list' cellspacing='0' cellpadding='3' border='0' 
             width='100%' style='table-layout: fixed'>
	<tr bgcolor='&usr.obox-titlebg;' >
          <th style='width:20px'>&nbsp;</th>
	  <th style='width:10em; text-align:left;'>Id</th>
	  <th style='width: auto; text-align:left'>Patch Name</th>
	  <th style='width:20px;text-align:right'>
            <input type='checkbox' 
                   name='install'
                   id='install_all'
                   onclick='checkall(\"install\")'/>
          </th>
	</tr>
";
    res += list_patches(id, plib, "imported");
    res += #"
      </table>
    </box-frame>

    <br clear='all' />
    <br />

    <font size='+1'><b>Installed Patches</b></font>
    <p>
      Click on a Patch for more information.
    </p>
    <input type='hidden' name='action' value='&form.action;'/>
    <input type='hidden' name='class' value='&form.class;'/>
    <box-frame width='100%' iwidth='100%' bodybg='&usr.contentbg;'
	       box-frame='yes' padding='0'>
      <table class='module-list' cellspacing='0' cellpadding='3' border='0' 
             width='100%' style='table-layout: fixed'>\n
	<tr bgcolor='&usr.obox-titlebg;' >
          <th style='width:20px'>&nbsp;</th>
	  <th style='width:10em; text-align:left;'>Id</th>
	  <th style='width:auto; text-align:left'>Patch Name</th>
	  <th style='width:16em; text-align:left'>Time of Installation</th>
	  <th style='width:20px; text-align:right'>
            <input type='checkbox'
                   name='uninstall'
                   id='uninstall_all'
                   onclick='checkall(\"uninstall\")'/>
          </th>
	</tr>
";
    res += list_patches(id, plib, "installed");
    res += #"      
      </table>
    </box-frame>

    <br clear='all' />
    <br />
    <link-gbutton href='./?class=" + action + #"'>Back</link-gbutton>
";
  }
  return res;
}