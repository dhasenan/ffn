module adapter.ffn;

import adapter.core;
import domain;

import core.time;
import std.experimental.logger;
import std.string;

import arsd.dom;
import url;

/**
    An adapter for fanfiction.net.
*/
class FFNAdapter : SimpleAdapter
{
    this()
    {
        acceptedDomain = "www.fanfiction.net";
        super.authorSelector = "#profile_top a.xcontrast_txt[href]";
        super.titleSelector = "#profile_top b.xcontrast_txt";
        super.chapterTitleSelector = "select#chap_select option[selected]";
        super.slugSelector = "#profile_top div.xcontrast_txt";
        super.chapterBodySelector = "#storytext";
    }

    override string chapterTitle(Element doc)
    {
        // So, the markup here is utter garbage.
        // Specifically:
        // <select>
        //   <option>look Ma, no closing tag!
        //   <option selected>still no closing tag!
        //   <option>...
        // </select>
        //
        // dom.d parses it as heavy nesting:
        // <select>
        //   <option>
        //     look Ma, no closing tag!
        //     <option>
        //       still no closing tag!
        //       <option>
        //         ...
        //       </option>
        //     </option>
        //   </option>
        // </select>
        auto roots = doc.querySelectorAll("select#chap_select option");

        foreach (root; roots)
        {
            if (root.hasAttribute("selected"))
            {
                return root.directText;
            }
        }
        return "(nameless chapter)";
    }

    /*
        We need some custom logic for chapter URLs because ffn doesn't have direct links
        in one page. It doesn't have *any* links, just javascript everywhere.
    */
    override URL[] chapterURLs(Element doc, URL u)
    {
        auto parts = u.path.split("/");
        auto basePath = "/" ~ parts[1] ~ "/" ~ parts[2] ~ "/";
        // We do it this way because there are two <select id="chap_select"> things.
        // There should only be one element with a given ID in a document...
        auto elems = doc.querySelector("select#chap_select").querySelectorAll("option");
        tracef("%s", elems.length);
        URL[] urls;
        foreach (elem; elems)
        {
            tracef("elem %s value is %s", elem, elem.getAttribute("value"));
            auto chap = u;
            chap.path = basePath ~ elem.getAttribute("value");
            urls ~= chap;
        }
        if (urls.length == 0)
        {
            // This is a single-chapter fic. The input URL is the only URL.
            urls ~= u;
        }
        return urls;
    }

    override Duration betweenDownloads()
    {
        return 500.msecs;
    }
}

unittest
{
    auto adapter = new FFNAdapter;
    auto doc = new Document(html).root;
	assert(adapter.chapterTitle(doc) == "9. Strange and Dangerous: Chapter 1");
	assert(adapter.title(doc) == "Scribble Pad");
	assert(adapter.author(doc) == "White Squirrel");
	assert(adapter.slug(doc) == "An anthology of chapters I wrote for stories that ultimately didn't go anywhere, but might still be worth posting. Free to anyone who wants them.");
}
version (unittest) enum html = `
<!DOCTYPE html><html><head>
        <meta charset='utf-8'>
        <META NAME='ROBOTS' CONTENT='NOARCHIVE'>
        <META http-equiv='X-UA-Compatible' content='IE=edge'>
        <META NAME='format-detection' content='telephone=no'>
        <META NAME='viewport' content='width=device-width'><link rel="canonical" href="//www.fanfiction.net/s/12999698/9/Scribble-Pad">
<title>Scribble Pad Strange and Dangerous: Chapter 1, a harry potter fanfic | FanFiction</title>

        <link rel='shortcut icon'  href='/static/images/favicon_2010_site.ico'>
        <link rel='icon' type='image/png' href='/static/images/favicon_2010_site.png'>
        <link rel='apple-touch-icon' href='/static/images/favicon_2010_iphone.png'>
       

        <link rel='stylesheet' href='/static/styles/xss25.css'>
        <script src='/static/scripts/combo3.js'></script>
        <!--[if lt IE 8]>
        <link rel="stylesheet" href="/cors/fontello-f1bf7dee/css/fontello-ie7.css">
        <script src='/static/scripts/json2.min.js'></script>
        <![endif]-->

        
        <script>
        xcookie_read();
        xfont_auto_loader();
        if(XCOOKIE.gui_font != 'Open Sans') {
            document.write('<style>body{font-family:"'+XCOOKIE.gui_font+'",Verdana, Arial;}</style>');
        }
        </script>
        <!-- startz --><script async src="//pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script><!-- endz -->
        <style>
        .dropdown-menu > li > a { padding: 3px 50px 3px 30px; }
body { min-width:750px; height:100%; }
.maxwidth { min-width:730px;margin-left:auto;margin-right:auto;}
            


        </style>
        <script>
        if(isAndroid && !isChrome) {
            document.write('<style> body {font-size:1em;}</style>');
        }
        </script>
        <script>

                        xauto_width_init();
                        xauto_fontsize();

                        if(!isIphone && !isIpad) {
                            $(function() {
                                $(window).resize(xauto_width);
                            });
                        }

                    </script></head><body style='background-color:#E4E3D5;margin-top:0px;'  ><script>xfont_fix_smooth();</script>


<div id=top style='width:100%;background-color: #333399; ' >
<div class='menulink maxwidth' style='padding:0.5em 10px 0.5em 10px; vertical-align:middle;'>

        <script>
//init jquery
if (!window.jQuery) {
  var jq = document.createElement('script'); jq.type = 'text/javascript';
  jq.src = '//ajax.googleapis.com/ajax/libs/jquery/1.11.0/jquery.min.js';
  document.getElementsByTagName('head')[0].appendChild(jq);
  console.log('loading preq: jquery');
}


 var _fp = {
    logout : function() {
            $.get('/logout.php', function() {
            console.log('starting logout');
                     var m = $('#_fp_modal_logged_out');
                    if(!m.length) {
                        $('body').append("<div id='_fp_modal_logged_out' data-backdrop='static' class='modal fade hide'><div class='modal-body'><div align=cener>You have successfully logged out. <span onClick='' type=button class='btn icon-edit-1'>Login</span> <span onClick='' type=button class='btn icon-edit-1'>Stay on this Page</span></div></div></div>");
                        m = $('#_fp_modal_logged_out');
                    }

                    m.modal();

                     console.log('modal finished');
                    //xtoast('You have been logged out.');
                    if(_fp.cb_loggedout) _fp.cb_loggedout();
                     console.log('callback complete');
            })
          .fail(function() {
            //m.modal('hide');
            xtoast('An error has ocurred. Please try again later.');
          });
            //
    }
};

//real function


        </script>
        
<script>
function render_login(uname) {
     var s = "<a href='/login.php' style='color:orange;'>"+uname+"</a> | <span id='' xonClick='_fp.logout();' onclick=\"location = '/logout.php';\" style='color:white;cursor: pointer;'>Logout</span>";
     return s;
}

</script>
<span id=name_login class=pull-right>
<script>
if(XUNAME) {
    document.write(render_login(XUNAME));
}
else {
    document.write("<a href='/login.php' style='color:white;'><span class='icon-lock' style='font-size:15px;position:relative;top:1px'></span> Login</a> | <a href='/signup.php' style='color:white;'>Sign Up</a>");
}
</script></span><a href='/' style='font-size:1.1em;border:none;'>FanFiction</a>&#160;&#160;<small>|</small>&#160;&#160;unleash your imagination <span class='icon-kub-mobile' style='font-size:14px;margin-left:10px;' title='Mobile Edition'  onclick="location = '//m.fanfiction.net/m/yes_mobile.php'"></span><span title='Fontastic Panel: UI Settings' class='icon-tl-text' style='font-size:14px;margin-left:10px;' onClick="_fontastic_init('ui'); $('#_fontastic_ui').modal('show');"></span></div>
</div>

<div style='width:100%;' class=zmenu>
    <div  id=zmenu  class='maxwidth' style='vertical-align:middle;padding:5px;'>
<span class=zui >

<!-- new stuff -->
<table class='maxwidth'><tr><td valign=middle >


            <div class='dropdown xmenu_item'>
                    <a class='dropdown-toggle' data-toggle='dropdown' href='#'>Browse <b class='caret'></b></a>
                    <ul class='dropdown-menu'>

            <li class=disabled style='text-align:center'><a href='#'>Stories</a></li>

            <li><a href='/anime/'>Anime</a></li>
            <li><a href='/book/'>Books</a></li>
            <li><a href='/cartoon/'>Cartoons</a></li>
            <li><a href='/comic/'>Comics</a></li>
            <li><a href='/game/'>Games</a></li>
            <li><a href='/misc/'>Misc</a></li>
            <li><a href='/play/'>Plays</a></li>
            <li><a href='/movie/'>Movies</a></li>
            <li><a href='/tv/'>TV</a></li>
            <li class='disabled' style='text-align:center'><a href='#'>Crossovers</a></li>

            <li><a href='/crossovers/anime/'>Anime</a></li>
            <li><a href='/crossovers/book/'>Books</a></li>
            <li><a href='/crossovers/cartoon/'>Cartoons</a></li>
            <li><a href='/crossovers/comic/'>Comics</a></li>
            <li><a href='/crossovers/game/'>Games</a></li>
            <li><a href='/crossovers/misc/'>Misc</a></li>
            <li><a href='/crossovers/play/'>Plays</a></li>
            <li><a href='/crossovers/movie/'>Movies</a></li>
            <li><a href='/crossovers/tv/'>TV</a></li>

               

                    </ul>
                </div>
                <div class='dropdown xmenu_item'>
                    <a class='dropdown-toggle' data-toggle='dropdown' href='#'>Just In <b class='caret'></b></a>
                    <ul class='dropdown-menu'>
            <li><a href='/j/0/0/0/'>All</a></li>

            <li><a href='/j/0/1/0/'>Stories: New</a><li>
            <li><a href='/j/0/2/0/'>Stories: Updated</a></li>

            <li class='divider'></li>
            <li><a href='/j/0/3/0/'>Crossovers: New</a><li>
            <li><a href='/j/0/4/0/'>Crossovers: Updated</a><li>

                    </ul>
                </div>
                <div class='dropdown xmenu_item'>
                    <a class='dropdown-toggle' data-toggle='dropdown' href='#'>Community <b class='caret'></b></a>
                    <ul class='dropdown-menu'>
            <li><a href='/communities/general/0/'>General</a></li>
            <li><a href='/communities/anime/'>Anime</a></li>
            <li><a href='/communities/book/'>Books</a></li>
            <li><a href='/communities/cartoon/'>Cartoons</a></li>
            <li><a href='/communities/comic/'>Comics</a></li>
            <li><a href='/communities/game/'>Games</a></li>
            <li><a href='/communities/misc/'>Misc</a></li>
            <li><a href='/communities/movie/'>Movies</a></li>
            <li><a href='/communities/play/'>Plays</a></li>
            <li><a href='/communities/tv/'>TV</a></li>
                    </ul>
                </div>
                <div class='dropdown xmenu_item'>
                    <a class='dropdown-toggle' data-toggle='dropdown' href='#'>Forum <b class='caret'></b></a>
                    <ul class='dropdown-menu'>
            <li><a href='/forums/general/0/'>General</a></li>
            <li><a href='/forums/anime/'>Anime</a></li>
            <li><a href='/forums/book/'>Books</a></li>
            <li><a href='/forums/cartoon/'>Cartoons</a></li>
            <li><a href='/forums/comic/'>Comics</a></li>
            <li><a href='/forums/game/'>Games</a></li>
            <li><a href='/forums/misc/'>Misc</a></li>
            <li><a href='/forums/movie/'>Movies</a></li>
            <li><a href='/forums/play/'>Plays</a></li>
            <li><a href='/forums/tv/'>TV</a></li>           </ul>
                </div>

                 <div class='dropdown xmenu_item'>
                    <a class='dropdown-toggle' data-toggle='dropdown' href='#'>Betas <b class='caret'></b></a>
                    <ul class='dropdown-menu'>

            <li class=disabled style='text-align:center'><a href='#'>All</a></li>

            <li><a href='/betareaders/all/anime/'>Anime</a></li>
            <li><a href='/betareaders/all/book/'>Books</a></li>
            <li><a href='/betareaders/all/cartoon/'>Cartoons</a></li>
            <li><a href='/betareaders/all/comic/'>Comics</a></li>
            <li><a href='/betareaders/all/game/'>Games</a></li>
            <li><a href='/betareaders/all/misc/'>Misc</a></li>
            <li><a href='/betareaders/all/play/'>Plays</a></li>
            <li><a href='/betareaders/all/movie/'>Movies</a></li>
            <li><a href='/betareaders/all/tv/'>TV</a></li>
            <li class='disabled' style='text-align:center'><a href='#'>Specific</a></li>

            <li><a href='/betareaders/anime/'>Anime</a></li>
            <li><a href='/betareaders/book/'>Books</a></li>
            <li><a href='/betareaders/cartoon/'>Cartoons</a></li>
            <li><a href='/betareaders/comic/'>Comics</a></li>
            <li><a href='/betareaders/game/'>Games</a></li>
            <li><a href='/betareaders/misc/'>Misc</a></li>
            <li><a href='/betareaders/play/'>Plays</a></li>
            <li><a href='/betareaders/movie/'>Movies</a></li>
            <li><a href='/betareaders/tv/'>TV</a></li>

               

                    </ul>
                </div>
        </td>
        <td valign=middle>

            <script>
                $(document).ready(function() {
                    $('.xdrop_search').click(function() {
                        var v = $(this).html();;

                        $('#search_type').val(v.toLowerCase());
                        $('#search_head').html(v);
                    });

                    $('#search_keywords').onEnterKey(function(){
                        $('form#search_form').submit();
                    });

                });

            </script>
            <FORM method=get id=search_form action='/search/' class='pull-right'>
                <div class='input-prepend'>
                    <div class='btn-group'>
                        <button class='btn dropdown-toggle' data-toggle='dropdown'>
                            <span id=search_head>Story</span>
                            <span class='caret'></span>
                        </button>
                        <ul class='dropdown-menu'>
                            <li><a href='#' class=xdrop_search>Story</a></li>
                            <li><a href='#' class=xdrop_search>Writer</a></li>
                            <li><a href='#' class=xdrop_search>Forum</a></li>
                            <!-- <li class='divider'></li> -->
                            <li><a href='#' class=xdrop_search>Community</a></li>
                        </ul>
                    </div>
                    <input class='span2' name='keywords' id=search_keywords type='text' placeholder='Search' title='Search'>
                    <!--  input-append <button class='btn' type='submit'>Go</button> -->
                </div>
                <!-- <input class=searchfield type=text name='keywords' placeholder='Search' title='Search' style='width:100px'> -->
                <input type=hidden name=ready value=1>
                <input type=hidden name=type id=search_type value=story>
            </FORM>
        </td>
    </tr>
</table>

</span>
</div>
</div>
<div style='width:100%;' class=xcontrast_outer id=content_parent><div class='xcontrast maxwidth' id=content_wrapper style='background-color: white;'><div id=content_wrapper_inner style='padding:0.5em;'>
<script>
if(XCOOKIE.read_theme == 'dark') {
     $(function(){
        _fontastic_change_theme('dark');

     });
 }
 else if(XCOOKIE.read_light_texture) {
   _fontastic_change_texture(XCOOKIE.read_light_texture);
 }

 </script><div style='margin-bottom: 10px' class='lc-wrapper' id=pre_story_links><span class=lc-left><a class=xcontrast_txt href='/book/'>Books</a><span class='xcontrast_txt icon-chevron-right xicon-section-arrow'></span><a class=xcontrast_txt href="/book/Harry-Potter/">Harry Potter</a>
</span>
</div>
<script>
//_fontastic_theme_css();

function toggleTheme() {
    if(XCOOKIE.read_theme == 'light') {
        _fontastic_change_theme('dark');
    }
    else {
        _fontastic_change_theme('light');
    }
}
</script><div id=img_large class='hide modal fade' style='color:black;'><div class='modal-body' align=center><img class='lazy cimage ' style='padding:2px;border:1px solid #ccc;-moz-border-radius:2px;-webkit-border-radius:2px;' src='/static/images/d_60_90.jpg' data-original='//ffcdn2012t-fictionpressllc.netdna-ssl.com/image/1674439/180/' width=180 height=240></div></div><div id=profile_top style='min-height:112px;'><span style='cursor:pointer;' title='Click for Larger Image' onclick="var t = $('#img_large img');t.prop('src',t.attr('data-original'));$('#img_large').modal();"><img class='cimage ' style='clear:left;float:left;margin-right:3px;padding:2px;border:1px solid #ccc;-moz-border-radius:2px;-webkit-border-radius:2px;' src='//ffcdn2012t-fictionpressllc.netdna-ssl.com/image/1674439/75/' width=75 height=100></span><button class='btn pull-right icon-heart' type=button onClick='$("#follow_area").modal();'> Follow/Fav</button><b class='xcontrast_txt'>Scribble Pad</b>
<span class='xcontrast_txt'><div style='height:5px'></div>By:</span> <a class='xcontrast_txt' href='/u/5339762/White-Squirrel'>White Squirrel</a> <span class='icon-mail-1  xcontrast_txt' ></span> <a class='xcontrast_txt' title="Send Private Message" href='https://www.fanfiction.net/pm2/post.php?uid=5339762'></a>
<div style='margin-top:2px' class='xcontrast_txt'>An anthology of chapters I wrote for stories that ultimately didn't go anywhere, but might still be worth posting. Free to anyone who wants them.</div>
<span class='xgray xcontrast_txt'>Rated: <a class='xcontrast_txt' href='https://www.fictionratings.com/' target='rating'>Fiction  T</a> - English -  Harry P. - Chapters: 11   - Words: 55,275 - Reviews: <a href='/r/12999698/'>163</a> - Favs: 110 - Follows: 166 - Updated: <span data-xutime='1536107877'>9/4</span> - Published: <span data-xutime='1531445495'>7/12</span> - id: 12999698 </span>
</div>
<div align=center class='lc-wrapper' style='margin-top:2em' ;'><div class='lc'>
<span class='xcontrast_txt'><span class='icon-tl-text' style='font-size:14px;cursor:pointer;' title="+ Font Size" onClick="_fontastic_change_size('u');" ></span>+</span>&#160;&#160;<span class='xcontrast_txt'><span class='icon-tl-text' style='font-size:14px;cursor:pointer;' title="- Font Size" onClick="_fontastic_change_size('d');" ></span>-</span>&#160;&#160;<span style='font-size:14px;cursor:pointer;' class='icon-tl-text xcontrast_txt' onclick="_fontastic_init('reading');$('#_fontastic_reading').modal('show');"  title="Fonts"></span>&#160;&#160;

<span class='icon-align-justify xcontrast_txt' onclick="$('#f_width').slideToggle();" style='font-size:14px' title="Story Width"></span> <span id=f_width class='hide xcontrast_txt'><span  onclick='_fontastic_change_width(100);'>Full</span> <span onclick='_fontastic_change_width(75);'>3/4</span> <span  onclick='_fontastic_change_width(50);'>1/2</span></span> &#160;&#160; <span class='icon-tl-text-height xcontrast_txt' onclick="$('#f_size').slideToggle();" style='font-size:14px;cursor:pointer;' title="Line Spacing"></span> <span id=f_size class='hide xcontrast_txt'> <span onclick='_fontastic_change_line_height("u");'>Expand</span> <span onclick='_fontastic_change_line_height("d");'>Tighten</span></span>&#160;&#160;<span class='xcontrast_txt icon-tl-contrast' onclick="toggleTheme();" style='margin-left:2px;margin-right:2px;font-size:14px;' align=absmiddle title="Story Contrast"></div></div>
    <span style='float:right; ' ><button class=btn TYPE=BUTTON  onClick="self.location='/s/12999698/8/Scribble-Pad'">&lt; Prev</button> <SELECT id=chap_select title="Chapter Navigation" Name=chapter onChange="self.location = '/s/12999698/'+ this.options[this.selectedIndex].value + '/Scribble-Pad';"><option  value=1 >1. The Obligatory Time Travel Fic:Chapter 1<option  value=2 >2. The Obligatory Time Travel Fic:Chapter 2<option  value=3 >3. Forged in Fire: Chapter 1<option  value=4 >4. The Brothers Gaunt: Chapter 1<option  value=5 >5. The Brothers Gaunt: Chapter 2<option  value=6 >6. The Brothers Gaunt: Chapter 3<option  value=7 >7. The Brothers Gaunt: Chapter 4<option  value=8 >8. Ferte in Noctem Animam Meam: Chapter 1<option  value=9 selected>9. Strange and Dangerous: Chapter 1<option  value=10 >10. Wish Fulfilment: Chapter 1<option  value=11 >11. The Sorting Hat's Mistake</select> <button class=btn TYPE=BUTTON onClick="self.location='/s/12999698/10/Scribble-Pad'">Next &gt;</button></span><div style='height:5px'></div><script>
document.write('<style> .storytext { max-height: 999999px; width: '+XCOOKIE.read_width+'%; font-size:' + XCOOKIE.read_font_size + 'em; font-family: "'+XCOOKIE.read_font+'"; line-height: '+XCOOKIE.read_line_height+'; text-align: left;} </style>');

$(function() {
    $.get('/eye/2/1/51303206/12999698/');
});
</script>

<div role='main' aria-label='story content' class='storytextp' id='storytextp'  align=center style='padding:0 0.5em 0 0.5em;'>
<div class='storytext xcontrast_txt nocopy' id='storytext'><p>Disclaimer: Harry Potter is not mine, but JK Rowling's.</p><p>The opening quotes are taken from <em>Harry Potter and the Deathly Hallows</em> and <em>Fantastic Beasts and Where to Find Them</em>.</p><p>A/N: This was written before we knew that Credence survived the first <em>Fantastic Beasts</em> movie, and about half of it before the movie was released in the first place.</p><hr size=1 noshade><p><strong>Introduction</strong></p><p>The short version is, this is an Obscurial!Harry story, but there's a catch: I came up with the idea before the first <em>Fantastic Beasts</em> movie was released. It was originally solely based on Harry developing the same condition as Arianna, before we knew what that condition was. It was going to be a Tonks-centric story with Harry being adopted by Andromeda and Ted, with Nymphadora as his big sister. At Hogwarts, it would have been Hufflepuff!Harry with Justin, Susan, and Hannah as his close friends, and Dora staying on as McGonagall's assistant.</p><p>The problem was, <em>Fantastic Beasts</em> came out, and that was great because we found out a lot more about Obscurials, but it was a problem because I knew I'd have to include Newt and Tina Scamander in the story, and I felt like Newt's personality clashed with the plot I had been setting up. I can't exactly quantify that, but he seemed a little too quirky, perhaps, for the story I was trying to write. I tried to mesh the two together, but it just wasn't working for me. Plus, it would have been another Hogwarts-years story, which made me even less enthusiastic, so I dropped the idea.</p><p>It's a shame because I've been hoping someone else would write a full-length Obscurial!Harry story. The closest one I've seen is the <em>Obscure Guardian</em> series by startabby on AO3, which is decent, but it isn't really the full treatment I'm looking for. There's definitely an opening for one, but I haven't seen any yet, and I just don't think I'm the one to write it.</p><p>This is the only chapter I have for this story.</p><hr size=1 noshade><p><strong>Strange and Dangerous: Chapter 1</strong></p><p>"<em>When my sister was six years old, she was attacked, set upon, by three muggle boys. They'd seen her doing magic…What they saw scared them, I expect…they got a bit carried away trying to stop the little freak doing it.</em></p><p>"<em>It destroyed her, what they did: She was never right again. She wouldn't use magic, but she couldn't get rid of it; it turned inward and drove her mad, it exploded out of her when she couldn't control it, and at times she was strange and dangerous. But mostly she was sweet and scared and harmless."</em></p><hr size=1 noshade><p>"<em>Before wizards went underground, when we were still being hunted by muggles, young wizards and witches sometimes tried to suppress their magic to avoid persecution. So instead of learning to harness or to control their powers, they developed what was called an Obscurus."</em></p><hr size=1 noshade><p>For about four years, Harry Potter's life was one of the worst of any child's in Britain. And then, it was all downhill from there.</p><p>Vernon and Petunia Dursley wanted a perfectly normal life—wanted it with an unhealthy fixation borne of a reaction against the skeletons in Petunia's closet: a very much abnormal sister and her equally abnormal family. And when that sister's abnormality got her killed, they were saddled with her infant nephew against their will.</p><p>Petunia was determined that the skeletons in her closest should stay there, and she took that literally. Little Harry's cot was placed in the cupboard under the stairs, but unfortunately for Harry, sleeping in the cupboard under the stairs was just the start. Four years of only having his basic needs met, being spanked hard and often and unfairly, and not knowing love in any meaningful sense quickly took their toll on his mind, just as not being fed properly and being made to do all the chores he was physically able took their toll on his body.</p><p>Merope Gaunt, facing not too dissimilar hardship, felt her magic go dormant, weakening until she couldn't cast the simplest spells to support herself and her unborn son. The young Tom Riddle, in contrast, embraced his magic and used it to get what he wanted. In another life, Harry Potter, a boy who wore his emotions on his sleeve and was rubbish at Occlumency, would never have learnt the control needed to repress his magic, and it would have leaked out as accidental magic, turning his teacher's hair blue and Apparating him up to the school roof like any other magical child.</p><p>Unfortunately for Harry (and his relatives), the years of abuse <em>did</em> instill that desire for control in him. Accidental magic was punished swiftly and severely, and even though he didn't know what it was, his relatives ensured that he knew in no uncertain terms that any such strange incidents were a result of his "freakishness" and were to be condemned. Thus, when his magic tried to protect him, he fought against the unknown force that had so angered his aunt and uncle and took the abuse instead, and the accidental magic stopped—at least when he was awake.</p><p>When he was asleep, however, Harry's subconscious mind was in control, and his magic, repressed by abuse and his own efforts and fed by his darkest fears and pains, became twisted, dark, and lashed out at his oppressors. The modern Ministry of Magic should have detected the high levels of accidental magic and intervened before it got too bad, but with the wards around Privett Drive, their readings were a little off.</p><p>Any three-year-old in the magical world could have seen the danger, even if they had never heard the word <em>Obscurus</em>. Any competent magical parent and even a lot of the muggle ones could have figured out something was wrong when it was still at the level of night terrors accompanied by accidental magic—before it became terminal. And any half-witted muggle knew that increasingly strange and destructive things happening around an abused child were a recipe for disaster according to practically every book and movie ever.</p><p>Apparently, Vernon Dursley didn't have half a wit to spare.</p><p>It wasn't the first incident in which a dark, amorphous mass ripped the cupboard door from its hinges and embedded it in the opposite wall that did it. It wasn't when the dark mass blew out every light bulb in the house and the streetlights on the street outside. It wasn't even when Dudley's entire gang of six-year-old bullies was knocked flat by something no one could see. No, the final straw was when the Dursleys were awakened by a crash in the middle of the night, and looked out the window to see that Vernon's car looked as if a tree had fallen on it—except there was no tree.</p><p>The six-year-old Harry Potter knew he was in trouble when he was hauled from his cupboard and slammed against the wall. As usual, he didn't know what he was in trouble <em>for</em>, but that was the furthest thing from his mind right now.</p><p>"YOU LITTLE FREAK! I KNOW YOU DID IT!" Vernon bellowed. He'd brought his belt downstairs with him, and he made vicious use of it. Harry screamed and tried to cover his face. But then, something happened that the Dursleys hadn't seen directly: the lights flickered and dimmed, as if something were absorbing the light from them.</p><p>"Vernon, stop!" Petunia screamed, finally noticing something was wrong, but it was too little too late.</p><p>"I'LL TEACH YOU TO USE THAT DAMN MAGIC!" Vernon roared. In a rage, he did something he had not done before. He turned the belt around. Swinging as hard as he could, he struck with the buckle on Harry's back once. Twice. Three times.</p><p>"AHH! NO! PLEASE! STOP!" Harry cried. The lights went out completely and struggled to brighten again. A rumble went through the whole house and shook it to its foundations.</p><p>"VERNON!"</p><p>"DADDY!"</p><p>"STOP THAT! STOP THAT!" Vernon yelled. With a year's worth of pent-up frustration, he swung the belt again. "STOP—!"</p><p><em>Snap!</em></p><p>What seemed to be a dark, amorphous tentacle of shadow shot out from Harry's back and wrapped around the belt in midair.</p><p>"—that?"</p><p>And then it happened. Vernon Dursley had about half a second to realise just how big a mistake he had made before an enormous dark mass burst out of Harry's body, filled the room, and struck with the force of a freight train.</p><p><em>BOOOOOM!</em></p><p>An explosion as large as the one that had rocked Godric's Hollow five years ago tore through Number Four Privett Drive and shook the entire town of Little Whinging. Vernon's body was blasted out into the street along with the entire front wall of the house—official cause of death: massive blunt force trauma, although the coroner couldn't make sense of the strange, almost scale-like markings carved into his skin. Neighbours were awakened as pieces of the ceiling rained down all over the neighbourhood, and Petunia and Dudley were crushed when most of the upstairs collapsed onto the downstairs, later to be found with the same strange markings on their faces. In seconds, all three Dursleys, including all of Lily Potter's remaining relatives, were dead.</p><p>Five minutes later, a very old man with a long, white beard appeared out of nowhere in the middle of the wreckage with wand drawn. But he saw no Death Eaters and no Dark Mark, and the residue of dark magic was of a very different kind. He searched quickly, sifting through the horrific devastation, and in the middle, he found a little boy, lying in a crater, crying, delirious, and clutching his head.</p><p>Then, as the old man approached, he saw the buckle-shaped welts on the boy's bare back and the distinctive markings on the victim's bodies, and in that moment, Albus Dumbledore knew just how big a mistake <em>he</em> had made.</p><hr size=1 noshade><p>Dumbledore was in tears as he carried the unconscious Boy-Who-Lived into the Infirmary at Hogwarts. "Poppy, please come quickly!" he said.</p><p>"Albus, what—Merlin's beard!" Poppy Pomfrey cried as she saw the boy in his arms. "What happened? Here, put him on the bed. Who is that? Why did you bring him?"</p><p>The old wizard laid Harry gently on the nearest bed and tucked him in. Pulling Poppy back a pace, he told her quietly, "This is Harry Potter, Poppy. <em>Do not</em> wake him up," he warned.</p><p>"Harry Potter?" Poppy said. "What? Why? What's wrong?"</p><p>"I've made a terrible mistake, Poppy," he said quickly. "I responded to an alarm at the house where he was living with his relatives, only to find the house destroyed and young Harry the survivor."</p><p>Poppy gasped: "The whole house? Did Death Eaters find him after all these years? Did You-Know-Who come back?"</p><p>"Oh, how I wish it were that simple. The markings left on the bodies were unmistakable." He barely whispered the words. "It was an Obscurus."</p><p>Poppy turned deathly pale at the word and fell in a swoon to sit on the nearest bed. "How? Obscuri are so rare—oh, the poor boy! Why did this happen?"</p><p>"Abuse, I'm afraid," Albus said sadly, "as it nearly always is. Abuse that was far too much my fault for placing him with relatives who would do that to a child, all for the sake of a magical protection. Abuse that I fear my own actions helped make the Ministry blind to. And now, I fear I have done damage that can never be fixed—worse than even Voldemort did to him."</p><p>"Albus, I…I'd help if I could," Poppy said. "I can fix his injuries, but what else do you want me to do? There's no helping an Obscurial child. I don't know how to begin to treat him. No one does."</p><p>"That is where you are wrong," Albus said. "There are a few who have worked with Obscurial before. I have, but I am the least of those. I will ask the others I know to help. Things are not quite as hopeless as they appear."</p><p>This did little to assuage Poppy's despair. "If anyone can help him, it's you, Albus," she said, "but is he even safe to be here? I mean…an <em>Obscurus</em>…"</p><p>"If there were students here, I would be gravely concerned, but as the school is empty, Hogwarts is the best place for him. But I must go for help at once. Make sure he's comfortable. Make sure he doesn't panic. And Poppy, the boy's magic is dangerously unstable. You <em>must</em> keep him sedated until I return."</p><hr size=1 noshade><p>It was rare for Aberforth Dumbledore to see his brother come into his pub, but it was far rarer for him to see his brother in tears.</p><p>"Albus? Is that you?" he said with a concern he hadn't thought he'd still possessed. "Bloody hell, who died? You look like a wreck!"</p><p>Albus just shook his head as he took a seat at the bar. He didn't try to contradict his brother—which was rather worrying, actually. Aberforth briefly considered some bizarre ploy on his brother's part, but no, he seemed genuinely grief-stricking. Aberforth could think of only one reason why Albus would react like that without him knowing anything: Gellert had died in prison, and—</p><p>"Aberforth, I am in desperate need of your help."</p><p>—and those were the words he had never expected to hear. "…Uh…What?" he said.</p><p>"I have made a terrible, terrible mistake."</p><p><em>What? What? What?</em> It wasn't Gellert? What mistake could be big enough that Albus felt the need to confess it to his brother? Unfortunately, the only response he could come up with was, "Really? Well, it's not your first, is it? You ought to be able to handle that on your own."</p><p>"I will not argue with you, Abe. I am begging your help. In this matter, your skills are greater than mine."</p><p>"Oh, <em>really?</em> After all these years, you've found something I can do better than the great Albus Dumbledore." His tear-stricken brother just sat there. "Alright, I'll bite. Whose life did you ruin this time?"</p><p>"H-Harry Potter," Albus breathed.</p><p>"Harry Potter?" Aberforth said incredulously. "Your Golden Boy? The Boy-Who-Lived? You managed to screw <em>him</em> over? Good Lord, what happened to him?"</p><p>Then, something else unexpected happened. Albus leaned forward, clapped his trembling hands on Aberforth's shoulders, and whispered, "The same thing that happened to Ariana."</p><p>Aberforth's brilliant blue eyes widened to the size of saucers in shock and anger. He wanted to hex his fool of a brother into next week, and Albus would probably let him in his present state, but he forced the urge down. He was determined to be the better man and show that he had his priorities sorted. "We'll need Scamander, you know."</p><p>"I've already sent Fawkes with a letter to him."</p><p>"And we'll need <em>you</em> to butt out."</p><p>"Abe—"</p><p>"Don't Abe <em>me</em>, Albus. <em>You</em><em>'re</em> the one who screwed up with Ariana. <em>You</em> never understood her. You never tried to comfort her. You were just one more selfish wizard who saw her as a dangerous force to be feared and controlled."</p><p>"You know that's not true—" Albus said softly.</p><p>"Of course it is!" Abe snapped. "Or if you didn't at first, you certainly did after Mother died, and you gave up your plans of world domination for her. How <em>noble</em> of you."</p><p>"The two of you needed me—"</p><p>"Bah! I already had my O.W.L.s, and I could have taken care of her better than you ever could."</p><p>"It wasn't like that! I was protecting her from Gellert."</p><p>Abe stopped. "From Gellert?" he said.</p><p>Albus shook his head furiously. "Gellert never wanted to leave Arianna behind, Abe. He wanted to leave <em>you</em>. Ariana—he wanted to <em>use</em> her—the same way he wanted to use Credence Barebone. In her Obscurus form, she was more powerful than I am—more powerful than <em>he</em> was. She was to be his ultimate weapon, but she would have been miserable. I had to protect her from that. I should have told you years ago."</p><p>Abe fumed so furiously that the bar around him began to smolder. "Albus, so help me, if you tell me you killed her to 'protect' her—"</p><p>"Gellert killed her Abe. I told you that years ago, and I wasn't lying. He told me after our final duel that she threw herself in front of a curse meant for you."</p><p>They were both silent for a minute. Abe did remember that conversation. Ariana had sacrificed herself for him, in the end. Albus sighed heavily: "I told you I would not argue with you today, and I am already struggling to keep that promise. I wronged Ariana, Abe. I wronged her grievously when she was already ill. I will not make that same mistake again. I need your help to ensure that the boy remains well and that, perhaps, with modern healing and mind-healing techniques, he may recover enough to attend school."</p><p>"Attend school, Albus? Are you mad? It'll be a hard enough task just to keep him alive, not to mention the threat to others."</p><p>"I know that, Abe, but there is a longer-term concern that I cannot ignore."</p><p>"What?" Abe growled. "Another one of your schemes? Haven't you done enough to the boy already?"</p><p>"Enough, and more," Albus agreed, "I've become painfully aware of my own shortcomings tonight, but alas, this one is out of my hands. Aberforth…I never told you about the prophecy."</p><p>"Prophecy? What prophecy?"</p><p>"The prophecy of the one who will defeat Voldemort."</p><p>Aberforth processed this groaned: "Oh, bloody hell, you <em>really</em> bollocksed it up this time, didn't you?"</p><p>"As succinct as ever, Aberforth," Albus said.</p><p>Abe glared at him. "You're asking a lot, Albus…I'll do what I can, though."</p><hr size=1 noshade><p>Newton Scamander was surprised to see a phoenix burst into flame in the middle of his laboratory late in the evening when he ought to be going to bed—surprised and worried. Fawkes's arrival could only herald an urgent matter from Dumbledore. He read the letter the bird proffered him and sucked a breath in horror. He immediately began buttoning everything down in his case and hurried to wake his wife.</p><p>"Tina! Tina, wake up!" he called, shaking her. "We are needed at Hogwarts at once!"</p><p>"Hogwarts?" Tina said blearily. "Why? What's happening."</p><p>"Our worst-case scenario, I'm afraid," Newt replied. "We have an Obscurial in Britain."</p><p>Tina was wide awake at once and moving for her wand. Even after all these years, her Auror instincts hadn't dulled—she couldn't afford that, working around all the beasts her husband did. "An Obscurial?" she snapped. "How? Is it anyone we know?"</p><p>"Dumbledore said he'd explain when we got there, but he told me…Tina, he told me it's Harry Potter."</p><p>"Harry Potter?" she gasped. "The one who—"</p><p>"The very same. The Obscurus killed his foster family. He's stable for now, but he needs expert help immediately."</p><p>"Which is you, of course."</p><p>"Which is <em>us</em>, Tina. Come on."</p><p>The Scamanders hurried to Hogwarts, where they were greeted by a sight they hadn't seen in a long time, though at the same time not long enough: the Dumbledore Brothers standing together, looking very grim.</p><p>"Albus, I got your letter," Newt said. "Is the boy here."</p><p>"He's up in the Infirmary," Albus replied. "You're willing to help?"</p><p>"Of course we are," Tina said. "Well always help a child who's going through that, the poor dear."</p><p>"Let's go," Newt started for the Infirmary. "What happened, and how is he doing, Albus?"</p><p>Dumbledore quickly explained what he had seen on Privet Drive as they made their way to the Infirmary, not glossing over his own part in the matter. Tina started to chew him out for screwing up a simple child placement, but she didn't really have time to get warmed up before they arrived. Newt quickly made his way to Harry's bedside to examine his new charge. Madam Pomfrey had healed his bruises and other injuries, and while he still looked thin and pale, he slept peacefully on the bed, looking perfectly harmless.</p><p>"He's doing as well as he can be, considering the circumstances," Pomfrey said. "What do you make of it?"</p><p>Newt waved his wand over the boy a few times. "He's exhausted," he concluded. "Even an Obscurus tires out after a while. He should sleep until morning, although you should give him a small dose of Dreamless Sleep, just in case."</p><p>"Already done. I'm not risking an Obscurial nightmare in my Infirmary."</p><p>"Good. Well, Albus, I can tell he's magically very strong," Newt continued. "That's good for him—not so good for anyone around him. But we've caught it early. I think if we can help him face his fears and bring it under control, he might be able to overcome it."</p><p>Albus frowned. "You speak as if Harry will have to live with this illness indefinitely," he said, "You told me once that you thought you could remove an Obscurus without hurting the child."</p><p>"But I failed, Albus," Newt said sadly. "The Sudanese girl all those years ago—the shock of removing it killed her. I might be able to improve the process, but it still wouldn't be without risk, and it would have to wait till Harry's stronger to try it regardless. Modern Mind Healing techniques combined with the methods you used to help your sister plus have a better chance of success."</p><p>"Our sister killed our mother!" Aberforth protested.</p><p>"Which was a tragedy," he agreed, "but you still had a better track record with her than any other Obscurial I know about, and knowing what we've learnt since then, Harry should be better off still."</p><p>Albus nodded slowly: "If you believe you can help Harry in any way, Newt, I will support you. Just tell me what you need."</p><p>"A safe place for him to live," Newt said. "Not cut off from the world, but isolated enough that he won't hurt any neighbours if things go wrong. And equally important, he'll need a family. Not just guardians, even good ones, but a mother and father—preferably ones who knew the Potters—who are willing and able to give him all the love and care a young wizard could ask for. To give him the best possible chance of survival, he'll need a real family."</p><p>"The property I can do, Newt," Albus said, "but not much of his family is left. That's why I couldn't find a better placement for him in the first place…But I will examine the Potters' associates in the morning to see if any of them are able to provide for him."</p><hr size=1 noshade><p>Albus looked at many possibilities, but in the end, there really was no other option. He walked up the front steps of a small house in a quiet, spread-out muggle neighbourhood and knocked on the door.</p><p>"I got it!" a bubbly voice called from inside, and a moment later, a young, purple-haired teenager opened the door. Upon seeing Dumbledore, her hair turned white. "Headmaster?" she said. "Whatever it is, I didn't do it!"</p><p>Dumbledore forced a smile. "Good morning, Miss Tonks. Is your mother here?" he asked.</p><p>Nymphadora turned around and back into the house, yelling, "Mum! Dumbledore wants to talk to you!"</p><p>Andromeda Tonks came to the door a minute later. "Professor, what are you doing here?" she asked.</p><p>"I'm sorry to disturb you, Andromeda, but I must speak with you on a matter of some urgency." He glanced at Nymphadora, who was peeking around the doorway. "In private."</p><p>Andromeda looked back and closed the door behind her to keep her daughter out of the conversation and conjured a privacy screen around them. It was now that she noticed the grave look on Dumbledore's face. "Professor, what's wrong?" she said. "Has something happened?"</p><p>"I'm afraid it has, Andromeda. I'm sorry to report that last night, the muggle relatives of Harry Potter, whom he was living with, were killed."</p><p>"My God," she gasped. "Harry Potter? Was it Death Eaters?"</p><p>He shook his head: "Would that it were that simple."</p><p>"Is Harry alright, at least? Is he alive?"</p><p>"Alive, yes. Alright, no. Harry has developed a serious illness that requires expert healing from a trusted source—more than Madam Pomfrey can provide. I had hoped that given your connection to his family—"</p><p>"Yes, of course I'll help any way I can. But what kind of illness is it?"</p><p>Dumbledore had tears in his eyes as he answered: "I'm afraid Harry has developed an Obscurus."</p><p>Andromeda felt faint and nearly collapsed. What horrors had she fallen into? No one she knew at St. Mungo's had ever so much as seen an Obscurial child. "An Obscurus? Dumbledore, that's a terminal disease!" she said. "Not to mention dangerous!"</p><p>"Both facts are exaggerated," he replied. "There <em>are</em> techniques that can manage the disease, and there have been two known cases of an Obscurial surviving past the age of ten."</p><p>"They still died, didn't they?"</p><p>"Yes, but not from the disease. They were both murdered by people who feared and coveted their power. I believe that with adequate help, Harry may yet overcome it."</p><p>"You're insane."</p><p>"Perhaps."</p><p>She waited for him to say more—or leave—but he didn't. "What do you want me for?" she asked.</p><p>"I want you to help look after him."</p><p>"Now you're <em>really</em> insane," she said flatly.</p><p>"I know I have no right to ask this of you, Andromeda—no right to ask you to take on this kind of risk. Especially because it was my own mistakes that caused this mess in the first place. You would have help, I promise you. But the only other choice for Harry is an indefinite stay in St. Mungo's with a small chance for survival. The boy has no family left. Most of James and Lily's friends are dead or otherwise unsuitable. You are Harry's nearest surviving relative who isn't in Azkaban or married to a Death Eater. You could take him in, if only on a nominal basis, and give us the stability he needs for us to help him."</p><p>"Isn't there a procedure to place him with a guardian?" she pressed.</p><p>"Since he has no immediate family, he would be placed up for adoption by the Ministry, which is one of the worst things that could happen to him right now. Instability, uncertainty, the risk that his new guardians would be more interested in his fame than his well-being or would be those who line the pockets of the Ministry. This cannot happen. However, under certain laws, distant cousins have preference over strangers. Legally, that will be either you or Narcissa, and since the Potters didn't recognise you being disowned, you have the stronger claim. Moreover, with your Healer's training, there are few witches better equipped to handle a child with special needs, whereas your sister…"</p><p>"Cissy wouldn't know which end to put the nappy on without an elf to help her," Andromeda finished for him.</p><p>"Quite."</p><p>"But surely James and Lily made provisions for Harry's care."</p><p>"Yes, but the claim is yours there as well. The Potters listed a number of preferred guardians in their will. An unusual move, and not entirely enforceable, but given the state of the war, a reasonable one. Their list was Sirius Black, Remus Lupin, the Longbottoms, Peter Pettigrew, you and Edward, and, as a last resort, Lily's sister. You are the only ones left on the list who are in a position to take him."</p><p>"What about Lupin?"</p><p>"Confidentially, I'm afraid I must inform you that Remus Lupin is a registered werewolf. He is not eligible. James and Lily included him as a symbolic gesture." He paused and waiting to see if she had another objection, but she stayed silent, albeit still looking very unhappy with the idea. "You would not need to be Harry's primary caregivers—although it would certainly help—as long as he had stability and a loving family to support him. You would also not need to be his primary Healer. Indeed, I have already secured an expert to help."</p><p>"An expert in Obscurials?" Andromeda said in surprise. "Who?"</p><p>"Newt Scamander. He has more experience with Obscurials than anyone else alive. He may even be able to cure Harry completely, although that remains to be seen. He and his wife have already agreed to help. Additionally, I have secured my brother's help."</p><p>"Aberforth? How can he help?"</p><p>Dumbledore lowered his gaze. "One of those cases I mentioned, Andromeda—an Obscurial who survived past age ten—was my sister, Ariana."</p><p>Andromeda backed off a half step. She'd never imagined Albus Dumbledore had tragedy like that in his past. "I'm…I'm sorry," she stammered.</p><p>"It was a long time ago," he said, "and I'm afraid I was never very good with her, but Aberforth, he was the only one who could bring her out of it every time. Even Mother…failed. I know there is still something of the kind boy I once knew in my brother. He is willing to try, at least. So I assure you, if you do this, you will not be alone."</p><p>Andromeda closed her eyes and took a few deep breaths. She considered the possibilities. It didn't sound like as bad a deal as it had at first. Could she do it? Could she risk Nymphadora being around…that? Could she live up to James's and Lily's memories if she didn't?</p><p>She made her decision: "I'll have to talk it over with Ted, but…if he's comfortable with it, I'm willing to try."</p><p>Dumbledore sighed with relief: "Thank you Andromeda. Please come up to Hogwarts as soon as you're ready. There is little time to lose."</p><p>"When we're ready, you'll be the first to know, Professor."</p>
</div>
</div><div style='height:5px'></div><div style='clear:both;text-align:right;'><button class=btn TYPE=BUTTON  onClick="self.location='/s/12999698/8/Scribble-Pad'">&lt; Prev</button> <SELECT id=chap_select title="Chapter Navigation" Name=chapter onChange="self.location = '/s/12999698/'+ this.options[this.selectedIndex].value + '/Scribble-Pad';"><option  value=1 >1. The Obligatory Time Travel Fic:Chapter 1<option  value=2 >2. The Obligatory Time Travel Fic:Chapter 2<option  value=3 >3. Forged in Fire: Chapter 1<option  value=4 >4. The Brothers Gaunt: Chapter 1<option  value=5 >5. The Brothers Gaunt: Chapter 2<option  value=6 >6. The Brothers Gaunt: Chapter 3<option  value=7 >7. The Brothers Gaunt: Chapter 4<option  value=8 >8. Ferte in Noctem Animam Meam: Chapter 1<option  value=9 selected>9. Strange and Dangerous: Chapter 1<option  value=10 >10. Wish Fulfilment: Chapter 1<option  value=11 >11. The Sorting Hat's Mistake</select> <button class=btn TYPE=BUTTON onClick="self.location='/s/12999698/10/Scribble-Pad'">Next &gt;</button></div><div style='height:5px'></div>
<script>
    function review_init() {
         if(XUNAME) {
             $('#review_name').hide();
             $('#review_postbutton').html('Post Review as ' + XUNAME);
             $('.login_items').hide();
             $('#alert_subs').show();
         }
         else {
             $('#review_name').show();
             //$('#review_name').html("<input type=text name='name' placeholder='Name:'>");

             $('.login_items').show();
             $('#alert_subs').hide();
         }
    }

    //call back
    function login_success_default() {
        //$('#name_login').html(render_login(XUNAME));

        //focus on review
        $('#review_review').focus();

        //you have now logged in
        xtoast("You have logged-in as "+XUNAME+'.');

        //close all open dialogs
        //$('#please_login').modal('hide');



    }

    function login_success() {
         login_success_default();
         review_init();
    }

    function self_login(target) {
        xwindow('https://www.fanfiction.net/api/login_state_proxy.php?src=popup&target='+target,450,450);
    }

    function post_q() {
        if(!XUNAME) {
            please_login();
            return;
        }

        if($('#q_follow_author').prop('checked') == 0 && $('#q_follow_story').prop('checked') == 0 && $('#q_fav_author').prop('checked') == 0 && $('#q_fav_story').prop('checked') ==0) {
            xtoast('Please select at least one follow or favorite action');
            return;
        }

        $('#q_working').toggle();

        $.post('/api/ajax_subs.php', {
            storyid: storyid,
            userid: userid,

            authoralert: $('#q_follow_author').prop('checked') ? 1 : 0,
            storyalert: $('#q_follow_story').prop('checked') ? 1 : 0,
            favstory: $('#q_fav_story').prop('checked') ? 1 : 0,
            favauthor: $('#q_fav_author').prop('checked') ? 1 : 0
        },
        function(data) {
            //console.log(data);
            //alert(data);
            if(data.error) {
                $('#q_working').toggle();

                xtoast("We are unable to process your request due to an network error. Please try again later.");
            }
            else {
                xtoast("We have successfully processed the following:" + data.payload_data,3500);
                $('#q_working').toggle();
                $('#follow_area').modal('hide');
             }
        },
        'json'
        ).error(function() {
            xtoast("We are unable to process your request due to an network error. Please try again later.");

            $('#q_working').toggle();
        });
    }

    function please_login() {
         xtoast("Please login or signup to access this feature.");
    }

    function post_review() {
        var review = $('#review_review').val();
        var name = $('#review_name_value') ? $('#review_name_value').val() : '';

        //make sure we don't submit default
        if(review == '') {
            xtoast("Please type up your review for this story.");
            return;
        }

        $('#review_postbutton').html("Posting. Please wait...");
        $('#review_postbutton').prop('disabled',true);

        $.post('/api/ajax_review.php', {
            storyid: storyid,
            storytextid: storytextid,
            chapter: chapter,

            authoralert: $('#review_authoralert').prop('checked') ? 1 : 0,
            storyalert: $('#review_storyalert').prop('checked') ? 1 : 0,
            favstory: $('#review_favstory').prop('checked') ? 1 : 0,
            favauthor: $('#review_favauthor').prop('checked') ? 1 : 0,

            name: name,
            review: review
        },
        function(data) {
            //console.log(data);
            //alert(data);
            if(data.error) {
                $('#review_postbutton').html('Post Review as'+XUNAME);
                $('#review_postbutton').prop('disabled', false);

                xtoast("We are unable to post your review due to the following reason:<br><br>" + data.error_msg);
            }
            else {
                xtoast("The author would like to thank you for your continued support. Your review has been posted.",3500);
                review_success();
            }
        },
        'json'
        ).error(function() {
            xtoast("We are unable to process your review due to an network error. Please try again later.");

            $('#review_postbutton').html("Post Review as"+XUNAME);
            $('#review_postbutton').prop('disabled', false);
        });

    }

    function review_success() {
         $('#review').hide();
         $('#review_success').show();

         //must clear textarea of auto-save would save old data
         $('#review_review').val('');
         
if(!$.storage) {
    $.storage = new $.store();
    //console.log('new storage');
}
$.storage.del('review:12999698:9');
//console.log('del review:12999698:9');
        
    }

    function review_failure() {

    }

    $().ready(function() {
        review_init();
    });
</script>
<div id='review_success' style='display:none;width:500px;height:100px;clear:both;margin-right:auto;margin-left:auto;'>
    The author would like to thank you for your continued support. Your review has been posted.
</div>
<div id=review>
<table border=0 padding=0 cellspacing=0 style='width:100%;'> <!-- min-width:500px;max-width:975px;clear:both;margin-right:auto;margin-left:auto;-->
    <tr>
        <td width=336  valign=top>
                </td>
        <td width=10></td>
        <td valign=top>
            <div style='width:100%;max-width:700px;'>
            <table style='width:100%;'>
            <tr>
            <td colspan=2>

            <div id=review_name style=''> <!-- min-width:500px;max-width:975px;  style='padding:0.5em;width:98%;' -->
                <input class='input-block-level'  style='max-width:700px' type=text name='name' id='review_name_value' maxlength=16 placeholder="Name:" >
                <div style='height:4px'></div>
            </div>



            <textarea class='input-block-level' style='max-width:700px' rows=10 placeholder="Type your review for this chapter here..." name=review id=review_review></textarea>
            </td>
            </tr>
            <tr>
            <td style='vertical-align:middle;'>
                <div id='alert_subs' class='hide xcontrast_txt'>
                  Favorite :
                  Story <input style='margin:-2px 0 0 0' type=checkbox name=favstory id=review_favstory>
                  Author <input style='margin:-2px 0 0 0' type=checkbox name=favauthor id=review_favauthor>
                  &#160;
                  Follow :
                  Story <input style='margin:-2px 0 0 0' type=checkbox name=storyalert id=review_storyalert>
                  Author <input style='margin:-2px 0 0 0' type=checkbox name=authoralert id=review_authoralert>
                </div>
            </td>
            <td align=right>
            <!-- Split button -->
<div class='btn-group xreset-left'>
  <button type='button' class='btn icon-edit-1' onClick='post_review();' id=review_postbutton>Post Review</button>
  <button type='button' class='btn dropdown-toggle login_items' data-toggle='dropdown'>

    <span class='sr-only '>As</span>
     <span class='caret '></span>
  </button>
 <ul class='dropdown-menu' role='menu'>
                        <li><a href='#' onclick="self_login('self');" class=xdrop_login>FanFiction</a></li>
                        <li><a href='#' onclick="self_login('sister');" class=xdrop_login>FictionPress</a></li>
                        <li><a href='#' onclick="self_login('google');" lass=xdrop_login>Google</a></li>
                        <li><a href='#' onclick="self_login('facebook');" class=xdrop_login>Facebook</a></li>
                        <li><a href='#' onclick="self_login('twitter');" class=xdrop_login>Twitter</a></li>
                        <li><a href='#' onclick="self_login('amazon');" class=xdrop_login>Amazon</a></li>
                    </ul>
</div>


            </td>
            </tr>
            </table>
            </div>
        </td>
    </tr>
</table>
</div>

<!-- <div id='please_login' class='modal hide fade'></div> -->

<script src='/static/scripts/jquery.jstore_01_09_2012.js'></script>
<script>
$().ready(function(){

    if(!$.storage) {
        $.storage = new $.store(); //init
    }

    var t_read = $.storage.get('review:12999698:9');

    if(t_read && t_read.length > 0 ) {
        //alert('recovered data' + t_read);

        var temp = $('textarea#review_review').val(); //NO SPACES .replace(/^\s+|\s+$/g,'')

        if(!temp || temp.length == 0 || temp == "Type your comments here.") {
            //alert('set good');
            $('textarea#review_review').val(t_read);
            //console.log('got'+t_read);
        }
    }
    else {
        //alert('no data');
    }

    var rTimer = setInterval(saveReview, 2000); //every 2s

    function saveReview() {
        var temp = $('textarea#review_review').val();  //make sure we don't save spaces .replace(/^\s+|\s+$/g,'');

        if(temp && temp.length > 0 &&  temp != "Type your comments here.") {
            $.storage.set('review:12999698:9', temp);
            //console.log('set'+temp);
        }
    }
});
</script>
        <div style='height:15px'></div>
<div  align=center class=lc-wrapper><div class=lc>
<FORM name=myselect onsubmit='return false;'><TABLE style='min-width;400px;margin-left:auto;margin-right:auto;' cellpadding=4>
            <TR>
                <TD>
                <script>
  var storyid = 12999698;
  var userid = 5339762;
  var storytextid = storytextid=51303206;
  var chapter = 9;
  var title = 'Scribble+Pad';
  var logind = 'https://www.fanfiction.net';


function select_drop(sel_value) {
  var t;

  if (sel_value == 'abuse') {
      t = xwindow(logind+'/report.php?chapter='+chapter+'&storyid='+storyid+'&title='+title,560,510);
  }
  else if (sel_value == 'c2') {
     t = xwindow(logind+'/c2_addstory.php?action=add&storyid='+storyid,560,470);
  }
}
</SCRIPT>
<div class='btn-group '  id='story_actions'>
    <div class='btn-group dropup'align=left>
    <button class='btn dropdown-toggle' data-toggle='dropdown'>
        <span >Actions</span>
        <span class='caret'></span>
    </button>
    <ul class='dropdown-menu' >
       <li><a onclick="select_drop('c2')">Add to Community</a></li>
        <li><a onclick="select_drop('abuse')">Report Abuse</a></li>
    </ul>
    </div>
</div>

<div class='btn-group '  id='share_providers'>
    <div class='btn-group dropup'align=left>
    <button class='btn dropdown-toggle' data-toggle='dropdown'>
        <span class='icon-share'> Share</span>

    </button>
    <ul class='dropdown-menu' >
        <li><a href='//plus.google.com/share?url=https%3A%2F%2Fwww.fanfiction.net%2Fs%2F12999698%2F9%2F' target=_new>Google+</a></li>
        <li><a href='//twitter.com/home?status=Reading+story%3A+https%3A%2F%2Fwww.fanfiction.net%2Fs%2F12999698%2F9%2F' target=_new>Twitter</a></li>
        <li><a href='//www.tumblr.com/share/link?url=https%3A%2F%2Fwww.fanfiction.net%2Fs%2F12999698%2F9%2F' target=_new>Tumblr</a></li>
        <li><a href='//www.facebook.com/sharer.php?u=https%3A%2F%2Fwww.fanfiction.net%2Fs%2F12999698%2F9%2F' target=_new>Facebook</a></li>
    </ul>
    </div>
</div>

<button class='btn icon-heart' type=button onClick='$("#follow_area").modal();'> Follow/Favorite</button>
<style>
    label input[type=checkbox]{
        position: relative;
        vertical-align: middle;
        bottom: -5px;
    }
</style>
<div class='modal fade hide' id=follow_area>
  <div class='modal-body'>
        <center>
        <table style='padding:6px;color:black !important;'>
        <tr><td valign=top>
        + Follow
        <hr>
          <label class='checkbox'>
            <input type='checkbox' id=q_follow_story> Story
           </label>
            <label class='checkbox'>
            <input type='checkbox' id=q_follow_author> Writer
           </label>
        </td>
        <td width=20></td>
        <td valign=top>
        + Favorite
        <hr>
             <label class='checkbox'>
            <input type='checkbox' id=q_fav_story> Story
           </label>
            <label class='checkbox'>
            <input type='checkbox' id=q_fav_author> Writer
           </label>
        </td>
        </tr>
        </table>
        </center>
  </div>
  <div class='modal-footer'>


    <span class='btn pull-left' data-dismiss='modal'>Close</span>
<span id='q_working' class='hide'>Working...&nbsp;&nbsp;</span>
    <span  class='btn btn-primary' onClick='post_q();'>Save</span>
  </div>

 </div>
</TD>
</TR>
</TABLE></form>
</div></div>
        <div style='height:5px'></div></div></div></div><div id=p_footer class=maxwidth style='clear:all;padding:1em 0 1em 0;'><div style='text-align:center'><a href='/support/'>Help</a> . <a href='/privacy/'>Privacy</a> . <a href='/tos/'>Terms of Service</a>  . <a href='#top'>Top</a></div><div style='height:10px'></div><div style='text-align:center'><a href='http://blog.fictionpress.com'><span class='icon-wordpress' style='color:rgb(104, 100, 100);font-size:18px;height:20px;width:20px;'></span></a>  <a href='//www.twitter.com/fictionpress'><span class='icon-twitter-3' style='color:rgb(104, 100, 100);font-size:18px;height:20px;width:20px;'></span></a></div><div style='height:15px'></div></div>
<script>
$(function() {
    $('img.lazy').lazyload({
        //skip_invisible : false
    });
});
</script>
        </body></html>
`;
