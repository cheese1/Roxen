//  Button module. Generates graphical buttons for use in Roxen config
//  interface, Roxen SiteBuilder and other places.
//
//  Copyright � 1999-2000 Roxen IS. Author: Jonas Walld�n, <jonasw@roxen.com>


//  Usage:
//
//  <gbutton
//     bgcolor         -- background color inside/outside button
//     textcolor       -- button text color
//     href            -- button URL
//     alt             -- alternative button alt text
//     border          -- image border
//     state           -- enabled|disabled button state
//     textstyle       -- normal|consensed text
//     icon-src        -- icon reference
//     icon-data       -- inline icon data
//     align           -- left|center|right text alignment
//     align-icon      -- left|center-before|center-after|right icon alignment
//     valign-icon     -- above|middle|below icon vertical alignment
//   >Button text</gbutton>
//
//  Alignment restriction: when text alignment is either left or right, icons
//  must also be aligned left or right.


constant cvs_version = "$Id: gbutton.pike,v 1.64 2000/11/17 15:56:30 anders Exp $";
constant thread_safe = 1;

#include <module.h>
inherit "module";

roxen.ImageCache  button_cache;

constant module_type = MODULE_TAG;
constant module_name = "GButton";
constant module_doc  = 
"Provides the <tt>&lt;gbutton&gt;</tt> tag that is used to draw graphical "
"buttons.";

mapping tagdocumentation() {
  Stdio.File file=Stdio.File();
  if(!file->open(__FILE__,"r")) return 0;
  string doc=compile_string("#define manual\n"+file->read())->gbuttonattr;
  string imagecache=button_cache->documentation();

  return ([

"gbutton":#"<desc cont='cont'><p><short>
 Creates graphical buttons.</short></p>
</desc>"

	   +doc
	   +imagecache,

"gbutton-url":#"<desc cont='cont'><p><short>
 Generates an URI to the button.</short> <tag>gbutton-url</tag> takes
 the same attributes as <xref href='gbutton.tag' /> including the
 image cache attributes.</p>
</desc>"

	   +doc
	   +imagecache,
  ]);
}

#ifdef manual
constant gbuttonattr=#"
<attr name='pagebgcolor' value='color'><p></p>

</attr>

<attr name='bgcolor' value='color'><p>
 Background color inside and outside button.</p>
<ex>
<gbutton bgcolor='lightblue'>Background</gbutton>
</ex>
</attr>

<attr name='textcolor' value='color'><p>
 Button text color.</p>
<ex>
<gbutton textcolor='#ff6600'>Text</gbutton>
</ex>
</attr>

<attr name=frame-image value='path'><p>
 Use this XCF-image as a frame for the button. The image is required
 to have at least the following layers: background, mask and
 frame.</p>

 <p>More information on how to create frame images can be found in the
 Roxen documentation; Web Site Creator/Graphical tags section.</p>
<ex>
<gbutton frame-image='internal-roxen-tabframe'>foo</gbutton>
</ex>
</attr>

<attr name='alt' value='string'><p>
 Alternative button and alt text.</p>
</attr>

<attr name='href' value='uri'><p>
 Button URI.</p>
</attr>

<attr name='textstyle' value='normal|condensed'><p>
 Set to <att>normal</att> or <att>condensed</att> to alter text style.</p>
</attr>

<attr name='width' value='number'><p>
 Minimum button width.</p>
</attr>

<attr name='align' value='left|center|right'><p>
 Set text alignment. There are some alignment restrictions: when text
 alignment is either <att>left</att> or <att>right</att>, icons must
 also be aligned <att>left</att> or <att>right</att>.</p>
</attr>

<attr name='state' value='enabled|disabled'><p>
 Set to <att>enabled</att> or <att>disabled</att> to select button state.</p>
</attr>

<attr name='icon-src' value='URI'><p>
 Fetch the icon from this URI.</p>
</attr>

<attr name='icon-data' value=''><p>
 Inline icon data.</p>
</attr>

<attr name='align-icon' value='left|center-before|center-after|right'><p>
 Set icon alignment.</p>

<table>
<tr><td>left</td><td>Place icon on the left side of the text.</td></tr>
<tr><td>center-before</td><td>Center the icon before the text.Requires the <att>align='center'</att> attribute.</td></tr>
<tr><td>center-after</td><td>Center the icon after the text. Requires the <att>align='center'</att> attribute.</td></tr>
<tr><td>right</td><td>Place icon on the right side of the text.</td></tr>
</table>

<ex>
<gbutton width='150' align-icon='center-before' icon-src='internal-roxen-help'>Roxen 2.0</gbutton>
</ex>
<ex>
<gbutton width='150' align='center' align-icon='center-after'
  icon-src='internal-roxen-help'>Roxen 2.0</gbutton>
</ex>
</attr>

<attr name='valign-icon' value='above|middle|below'><p>
  Set icon vertical alignment. Requires three horizontal guidelines in the
  frame image. If set to <att>above</att> the icon is placed between the first
  and second guidelines and the text between the second and third ones. If
  set to <att>below</att> the placement is reversed. Default value is
  <att>middle</att>.</p>
</attr>

<attr name='font' value='fontname'><p></p>

</attr>

<attr name='extra-layers' value='[''],[first|last],[selected|unselected],[background|mask|frame|left|right]'>
<p></p>
</attr>

<attr name='extra-left-layers' value='[''],[first|last],[selected|unselected],[background|mask|frame|left|right]'>
<p></p>
</attr>

<attr name='extra-right-layers' value='[''],[first|last],[selected|unselected],[background|mask|frame|left|right]'>
<p></p>
</attr>

<attr name='extra-background-layers' value='[''],[first|last],[selected|unselected],[background|mask|frame|left|right]'>
<p></p>
</attr>

<attr name='extra-mask-layers' value='[''],[first|last],[selected|unselected],[background|mask|frame|left|right]'>
<p></p>
</attr>

<attr name='extra-frame-layers' value='[''],[first|last],[selected|unselected],[background|mask|frame|left|right]'>
<p></p>
<ex>
<gbutton frame-image='gbutton.xcf' alt='foo'>bu</gbutton>
</ex>


<ex>
<gbutton  alt='Edit' bgcolor='#aeaeae'
  extra-background-layers='unselected background,last unselected background,last background' 
  extra-frame-layers='unselected frame,last unselected frame,last frame' 
  extra-layers='unselected,last unselected,last' 
  extra-left-layers='unselected left,last unselected left,last left'
  extra-mask-layers='unselected mask,last unselected mask,last mask'
  extra-right-layers='unselected right,last unselected right,last right' >Buttontext
</gbutton>
</ex>
</attr>

<!-- <table>
<tr><td>A</td><td>B</td><td>C</td></tr>
<tr><td>''</td><td>''</td><td>''</td></tr>
<tr><td>'first'</td><td>'selected'</td><td>'background'</td></tr>
<tr><td>'last'</td><td>'unselected'</td><td>'mask'</td></tr>
<tr><td></td><td></td><td>'frame'</td></tr>
<tr><td></td><td></td><td>'left'</td></tr>
<tr><td></td><td></td><td>'right'</td></tr>
</table> -->";
#endif

function TIMER( function f )
{
#if 0
  return lambda(mixed ... args) {
           int h = gethrtime();
           mixed res;
           werror("Drawing ... ");
           res = f( @args );
           werror(" %.1fms\n", (gethrtime()-h)/1000000.0 );
           return res;
         };
#endif
  return f;
}
void start()
{
  button_cache = roxen.ImageCache("gbutton", TIMER(draw_button));
}

string status() {
  array s=button_cache->status();
  return sprintf("<b>Images in cache:</b> %d images<br />\n<b>Cache size:</b> %s",
		 s[0]/2, Roxen.sizetostring(s[1]));
}

mapping(string:function) query_action_buttons() {
  return ([ "Clear cache":flush_cache ]);
}

void flush_cache() {
  button_cache->flush();
}

Image.Layer layer_slice( Image.Layer l, int from, int to )
{
  return Image.Layer( ([
    "image":l->image()->copy( from,0, to-1, l->ysize()-1 ),
    "alpha":l->alpha()->copy( from,0, to-1, l->ysize()-1 ),
  ]) );
}

Image.Layer stretch_layer( Image.Layer o, int x1, int x2, int w )
{
  Image.Layer l, m, r;
  int leftovers = w - (x1 + (o->xsize()-x2) );
  object oo = o;

  l = layer_slice( o, 0, x1 );
  m = layer_slice( o, x1+1, x2-1 );
  r = layer_slice( o, x2, o->xsize() );

  m->set_image( m->image()->scale( leftovers, l->ysize() ),
                m->alpha()->scale( leftovers, l->ysize() ));

  l->set_offset(  0,0 );
  m->set_offset( x1,0 );
  r->set_offset( w-r->xsize(),0 );
  o = Image.lay( ({ l, m, r }) );
  o->set_mode( oo->mode() );
  o->set_alpha_value( oo->alpha_value() );
  return o;
}

array(Image.Layer) draw_button(mapping args, string text, object id)
{
  Image.Image  text_img;
  mapping      icon;
  object       button_font = resolve_font( args->font );

  Image.Layer background;
  Image.Layer frame;
  Image.Layer mask;

  int left, right, top, middle, bottom; /* offsets */
  int req_width;

  mapping ll = ([]);

  void set_image( array layers )
  {
    foreach( layers||({}), object l )
    {
      if(!l->get_misc_value( "name" ) ) // Hm.
        continue;
      ll[lower_case(l->get_misc_value( "name" ))] = l;
      switch( lower_case(l->get_misc_value( "name" )) )
      {
       case "background": background = l; break;
       case "frame":      frame = l;     break;
       case "mask":       mask = l;     break;
      }
    }
  };

  if( args->border_image )
    set_image( roxen.load_layers(args->border_image, id) );

  //  otherwise load default images
  if ( !frame )
    set_image( roxen.load_layers("/internal-roxen-gbutton", id) );


  // Translate frame image to 0,0 (left layers are most likely to the
  // left of the frame image)

  int x0 = frame->xoffset();
  int y0 = frame->yoffset();
  if( x0 || y0 )
    foreach( values( ll ), object l )
    {
      int x = l->xoffset();
      int y = l->yoffset();
      l->set_offset( x-x0, y-y0 );
    }

  if( !mask )
    mask = frame;

  array x = ({});
  array y = ({});
  foreach( frame->get_misc_value( "image_guides" ), object g )
    if( g->pos < 4096 )
      if( g->vertical )
	x += ({ g->pos-x0 });
      else
	y += ({ g->pos-y0 });

  sort( y );
  sort( x );

  if(sizeof( x ) < 2)
    x = ({ 5, frame->xsize()-5 });

  if(sizeof( y ) < 2)
    y = ({ 2, frame->ysize()-2 });

  left = x[0]; right = x[-1];    top = y[0]; middle = y[1]; bottom = y[-1];
  right = frame->xsize()-right;

  //  Text height depends on which guides we should align to
  int text_height;
  switch (args->icva) {
  case "above":
    text_height = bottom - middle;
    break;
  case "below":
    text_height = middle - top;
    break;
  default:
  case "middle":
    text_height = bottom - top;
    break;
  }

  //  Get icon
  if (args->icn)
    icon = roxen.low_load_image(args->icn, id);
  else if (args->icd)
    icon = roxen.low_decode_image(args->icd);

  int i_width = icon && icon->img->xsize();
  int i_height = icon && icon->img->ysize();
  int i_spc = i_width && sizeof(text) && 5;

  //  Generate text
  if (sizeof(text))
  {
    text_img = button_font->write(text)->scale(0, text_height );
    if (args->cnd)
      text_img = text_img->scale((int) round(text_img->xsize() * 0.8),
				 text_img->ysize());
  }

  int t_width = text_img && text_img->xsize();

  //  Compute text and icon placement. Only incorporate icon width/spacing if
  //  it's placed inline with the text.
  req_width = t_width + left + right;
  if ((args->icva || "middle") == "middle")
    req_width += i_width + i_spc;
  if (args->wi && (req_width < args->wi))
    req_width = args->wi;

  int icn_x, icn_y, txt_x, txt_y;

  //  Are text and icon lined up or on separate lines?
  switch (args->icva) {
  case "above":
  case "below":
    //  Note: This requires _three_ guidelines! Icon and text can only be
    //  horizontally centered
    icn_x = left + (req_width - right - left - i_width) / 2;
    txt_x = left + (req_width - right - left - t_width) / 2;
    if (args->icva == "above") {
      txt_y = middle;
      icn_y = top + (middle - top - i_height) / 2;
    } else {
      txt_y = top;
      icn_y = middle + (bottom - middle - i_height) / 2;
    }
    break;

  default:
  case "middle":
    //  Center icon vertically on same line as text
    icn_y = icon && (frame->ysize() - icon->img->ysize()) / 2;
    txt_y = top;
    
    switch (args->al)
    {
    case "left":
      //  Allow icon alignment: left, right
      switch (args->ica)
      {
      case "left":
	icn_x = left;
	txt_x = icn_x + i_width + i_spc;
	break;
      default:
      case "right":
	txt_x = left;
	icn_x = req_width - right - i_width;
	break;
      }
    break;

    default:
    case "center":
    case "middle":
      //  Allow icon alignment:
      //  left, center, center-before, center-after, right
      switch (args->ica)
      {
      case "left":
	icn_x = left;
	txt_x = (req_width - right - left - i_width - i_spc - t_width) / 2;
	txt_x += icn_x + i_width + i_spc;
	break;
      default:
      case "center":
      case "center_before":
      case "center-before":
	icn_x = (req_width - i_width - i_spc - t_width) / 2;
	txt_x = icn_x + i_width + i_spc;
	break;
      case "center_after":
      case "center-after":
	txt_x = (req_width - i_width - i_spc - t_width) / 2;
	icn_x = txt_x + t_width + i_spc;
	break;
      case "right":
	icn_x = req_width - right - i_width;
	txt_x = left + (icn_x - i_spc - t_width) / 2;
	break;
      }
      break;
      
    case "right":
      //  Allow icon alignment: left, right
      switch (args->ica)
      {
      default:
      case "left":
	icn_x = left;
	txt_x = req_width - right - t_width;
	break;
      case "right":
	icn_x = req_width - right - i_width;
	txt_x = icn_x - i_spc - t_width;
	break;
      }
      break;
    }
    break;
  }

  if( args->extra_frame_layers )
  {
    array l = ({ });
    foreach( args->extra_frame_layers/",", string q )
      l += ({ ll[q] });
    l-=({ 0 });
    if( sizeof( l ) )
      frame = Image.lay( l+({frame}) );
  }

  if( args->extra_mask_layers )
  {
    array l = ({ });
    foreach( args->extra_mask_layers/",", string q )
      l += ({ ll[q] });
    l-=({ 0 });
    if( sizeof( l ) )
    {
      if( mask )
        l = ({ mask })+l;
      mask = Image.lay( l );
    }
  }

  right = frame->xsize()-right;
  frame = stretch_layer( frame, left, right, req_width );
  if (mask != frame)
    mask = stretch_layer( mask, left, right, req_width );

  array(Image.Layer) button_layers = ({
     Image.Layer( Image.Image(req_width, frame->ysize(), args->bg),
                  mask->alpha()->scale(req_width,frame->ysize())),
  });


  if( args->extra_background_layers || background)
  {
    array l = ({ background });
    foreach( (args->extra_background_layers||"")/","-({""}), string q )
      l += ({ ll[q] });
    l-=({ 0 });
    foreach( l, object ll )
    {
      if( args->dim )
        ll->set_alpha_value( 0.3 );
      button_layers += ({ stretch_layer( ll, left, right, req_width ) });
    }
  }


  button_layers += ({ frame });
  frame->set_mode( "value" );

  if( args->dim )
  {
    //  Adjust dimmed border intensity to the background
    int bg_value = Image.Color(@args->bg)->hsv()[2];
    int dim_high, dim_low;
    if (bg_value < 128) {
      dim_low = max(bg_value - 64, 0);
      dim_high = dim_low + 128;
    } else {
      dim_high = min(bg_value + 64, 255);
      dim_low = dim_high - 128;
    }
    frame->set_image(frame->image()->
                     modify_by_intensity( 1, 1, 1,
                                          ({ dim_low, dim_low, dim_low }),
                                          ({ dim_high, dim_high, dim_high })),
                     frame->alpha());
  }

  //  Draw icon.
  if (icon)
    button_layers += ({
      Image.Layer( ([
        "alpha_value":(args->dim ? 0.3 : 1.0),
        "image":icon->img,
        "alpha":icon->alpha,
        "xoffset":icn_x,
        "yoffset":icn_y
      ]) )});

  //  Draw text
  if(text_img)
    button_layers += ({
    Image.Layer(([
      "alpha_value":(args->dim ? 0.5 : 1.0),
      "image":text_img->color(0,0,0)->invert()->color(@args->txt),
      "alpha":text_img,
      "xoffset":txt_x,
      "yoffset":txt_y,
    ]))
  });

  // 'plain' extra layers are added on top of everything else
  if( args->extra_layers )
  {
    array q = map(args->extra_layers/",",
                  lambda(string q) { return ll[q]; } )-({0});
    foreach( q, object ll )
    {
      if( args->dim )
        ll->set_alpha_value( 0.3 );
      button_layers += ({stretch_layer(ll,left,right,req_width)});
    }
  }

  button_layers  -= ({ 0 });
  // left layers are added to the left of the image, and the mask is
  // extended using their mask. There is no corresponding 'mask' layers
  // for these, but that is not a problem most of the time.
  if( args->extra_left_layers )
  {
    array l = ({ });
    foreach( args->extra_left_layers/",", string q )
      l += ({ ll[q] });
    l-=({ 0 });
    if( sizeof( l ) )
    {
      object q = Image.lay( l );
      foreach( button_layers, object b )
      {
        int x = b->xoffset();
        int y = b->yoffset();
        b->set_offset( x+q->xsize(), y );
      }
      q->set_offset( 0, 0 );
      button_layers += ({ q });
    }
  }

  // right layers are added to the right of the image, and the mask is
  // extended using their mask. There is no corresponding 'mask' layers
  // for these, but that is not a problem most of the time.
  if( args->extra_right_layers )
  {
    array l = ({ });
    foreach( args->extra_right_layers/",", string q )
      l += ({ ll[q] });
    l-=({ 0 });
    if( sizeof( l ) )
    {
      object q = Image.lay( l );
      q->set_offset( button_layers[0]->xsize()+
                     button_layers[0]->xoffset(),0);
      button_layers += ({ q });
    }
  }

//   if( !equal( args->pagebg, args->bg ) )
//   {
  // FIXME: fix transparency (somewhat)
  // this version totally destroys the alpha channel of the image,
  // but that's sort of the intention. The reason is that
  // the png images are generated without alpha.
  if (args->format == "png")
    return ({ Image.Layer(([ "fill":args->pagebg, ])) }) + button_layers;
  else
    return button_layers;
//   }
}


mapping find_internal(string f, RequestID id)
{
  return button_cache->http_file_answer(f, id);
}


class ButtonFrame {
  inherit RXML.Frame;

  array mk_url(RequestID id) 
  {
    string fi = (args["frame-image"] ||
		 id->misc->defines["gbutton-frame-image"]);
    if( fi )
      fi = Roxen.fix_relative( fi, id );
    
    //  Harmonize some attribute names to RXML standards...
    args->icon_src = args["icon-src"] || args->icon_src;
    args->icon_data = args["icon-data"] || args->icon_data;
    args->align_icon = args["align-icon"] || args->align_icon;
    args->valign_icon = args["valign-icon"] || args->valign_icon;
    m_delete(args, "icon-src");
    m_delete(args, "icon-data");
    m_delete(args, "align-icon");
    
    mapping new_args = ([
      "pagebg" :parse_color(args->pagebgcolor ||
			    id->misc->defines->theme_bgcolor ||
			    id->misc->defines->bgcolor ||
			    args->bgcolor ||
			    "#eeeeee"),                 // _page_ bg color
      "bg"  : parse_color(args->bgcolor ||
			  id->misc->defines->theme_bgcolor ||
			  id->misc->defines->bgcolor ||
			  "#eeeeee"),                   //  Background color
      "txt" : parse_color(args->textcolor ||
			  id->misc->defines->theme_bgcolor ||
			  id->misc->defines->fgcolor ||
			  "#000000"),                   //  Text color
      "cnd" : (args->condensed ||                       //  Condensed text
	       (lower_case(args->textstyle || "") == "condensed")),
      "wi"  : (int) args->width,                        //  Min button width
      "al"  : args->align || "left",                    //  Text alignment
      "dim" : (args->dim ||                             //  Button dimming
	       (< "dim", "disabled" >)[lower_case(args->state || "")]),
      "icn" : args->icon_src &&
               Roxen.fix_relative(args->icon_src, id),  // Icon URL
      "icd" : args->icon_data,                          //  Inline icon data
      "ica" : lower_case(args->align_icon || "left"),   //  Icon alignment
      "icva": lower_case(args->valign_icon || "middle"),//  Vertical align
      "font": (args->font||id->misc->defines->font||
	       roxen->query("default_font")),
      "border_image":fi,
      "extra_layers":args["extra-layers"],
      "extra_left_layers":args["extra-left-layers"],
      "extra_right_layers":args["extra-right-layers"],
      "extra_background_layers":args["extra-background-layers"],
      "extra_mask_layers":args["extra-mask-layers"],
      "extra_frame_layers":args["extra-frame-layers"],
      "scale":args["scale"],
      "format":args["format"],
      "gamma":args["gamma"],
      "crop":args["crop"],
    ]);

    new_args->quant = args->quant || 128;
    foreach(glob("*-*", indices(args)), string n)
      new_args[n] = args[n];

    string img_src =
      query_internal_location() +
      button_cache->store( ({ new_args, content }), id);

    return ({ img_src, new_args });
  }
}

class TagGButtonURL {
  inherit RXML.Tag;
  constant name = "gbutton-url";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;
  RXML.Type content_type = RXML.t_text(RXML.PXml);

  class Frame {
    inherit ButtonFrame;
    array do_return(RequestID id) {
      result=mk_url(id)[0];
      return 0;
    }
  }
}

class TagGButton {
  inherit RXML.Tag;
  constant name = "gbutton";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;
  RXML.Type content_type = RXML.t_text(RXML.PXml);

  class Frame {
    inherit ButtonFrame;
    array do_return(RequestID id) {
      //  Peek at img-align and remove it so it won't be copied by "*-*" glob
      //  in mk_url().
      string img_align = args["img-align"];
      m_delete(args, "img-align");
      
      [string img_src, mapping new_args]=mk_url(id);

      mapping img_attrs = ([ "src"    : img_src,
			     "alt"    : args->alt || content,
			     "border" : args->border,
			     "hspace" : args->hspace,
			     "vspace" : args->vspace ]);
      if (img_align)
        img_attrs->align = img_align;
      
      if (mapping size = button_cache->metadata(new_args, id, 1)) {
	//  Image in cache (1 above prevents generation on-the-fly, i.e.
	//  first image will lack sizes).
	img_attrs->width = size->xsize;
	img_attrs->height = size->ysize;
      }

      result = Roxen.make_tag("img", img_attrs, !args->noxml);

      //  Make button clickable if not dimmed
      if(args->href && !new_args->dim)
      {
	mapping a_attrs = ([ "href" : args->href ]);

	foreach(indices(args), string arg)
	  if(has_value("target/onmousedown/onmouseup/onclick/ondblclick/"
		       "onmouseout/onmouseover/onkeypress/onkeyup/"
		       "onkeydown" / "/", lower_case(arg)))
	    a_attrs[arg] = args[arg];

	result = Roxen.make_container("a", a_attrs, result);
      }

      return 0;
    }
  }
}
