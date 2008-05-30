// html.rl written by Mitchell Foral. mitchell<att>caladbolg<dott>net.

/************************* Required for every parser *************************/
#ifndef RAGEL_HTML_PARSER
#define RAGEL_HTML_PARSER

#include "ragel_parser_macros.h"

// the name of the language
const char *HTML_LANG = "html";

// the languages entities
const char *html_entities[] = {
  "space", "comment", "doctype",
  "tag", "entity", "any"
};

// constants associated with the entities
enum {
  HTML_SPACE = 0, HTML_COMMENT, HTML_DOCTYPE,
  HTML_TAG, HTML_ENTITY, HTML_ANY
};

/*****************************************************************************/

#include "css_parser.h"
#include "javascript_parser.h"

%%{
  machine html;
  write data;
  include common "common.rl";
  #EMBED(css)
  #EMBED(javascript)

  # Line counting machine

  action html_ccallback {
    switch(entity) {
    case HTML_SPACE:
      ls
      break;
    case HTML_ANY:
      code
      break;
    case INTERNAL_NL:
      std_internal_newline(HTML_LANG)
      break;
    case NEWLINE:
      std_newline(HTML_LANG)
      break;
    case CHECK_BLANK_ENTRY:
      check_blank_entry(HTML_LANG)
    }
  }

  html_comment =
    '<!--' @comment (
      newline %{ entity = INTERNAL_NL; } %html_ccallback
      |
      ws
      |
      (nonnewline - ws) @comment
    )* :>> '-->';

  html_sq_str =
    '\'' @code (
      newline %{ entity = INTERNAL_NL; } %html_ccallback
      |
      ws
      |
      [^\t '\\] @code
      |
      '\\' nonnewline @code
    )* '\'';
  html_dq_str =
    '"' @code (
      newline %{ entity = INTERNAL_NL; } %html_ccallback
      |
      ws
      |
      [^\t "\\] @code
      |
      '\\' nonnewline @code
    )* '"';
  html_string = html_sq_str | html_dq_str;

  ws_or_inl = (ws | newline @{ entity = INTERNAL_NL; } %html_ccallback);

  html_css_entry = '<' /style/i [^>]+ :>> 'text/css' [^>]+ '>' @code;
  html_css_outry = '</' /style/i ws_or_inl* '>' @code;
  html_css_line := |*
    html_css_outry @{ p = ts; fgoto html_line; };
    # unmodified CSS patterns
    spaces      ${ entity = CSS_SPACE; } => css_ccallback;
    css_comment;
    css_string;
    newline     ${ entity = NEWLINE;   } => css_ccallback;
    ^space      ${ entity = CSS_ANY;   } => css_ccallback;
  *|;

  html_js_entry = '<' /script/i [^>]+ :>> 'text/javascript' [^>]+ '>' @code;
  html_js_outry = '</' /script/i ws_or_inl* '>' @code;
  html_js_line := |*
    html_js_outry @{ p = ts; fgoto html_line; };
    # unmodified Javascript patterns
    spaces     ${ entity = JS_SPACE; } => js_ccallback;
    js_comment;
    js_string;
    newline    ${ entity = NEWLINE;  } => js_ccallback;
    ^space     ${ entity = JS_ANY;   } => js_ccallback;
  *|;

  html_line := |*
    html_css_entry @{ entity = CHECK_BLANK_ENTRY; } @html_ccallback
      @{ fgoto html_css_line; };
    html_js_entry @{ entity = CHECK_BLANK_ENTRY; } @html_ccallback
      @{ fgoto html_js_line; };
    # standard HTML patterns
    spaces       ${ entity = HTML_SPACE; } => html_ccallback;
    html_comment;
    html_string;
    newline      ${ entity = NEWLINE;    } => html_ccallback;
    ^space       ${ entity = HTML_ANY;   } => html_ccallback;
  *|;

  # Entity machine

  action html_ecallback {
    callback(HTML_LANG, entity, cint(ts), cint(te));
  }

  html_entity := 'TODO:';
}%%

/************************* Required for every parser *************************/

/* Parses a string buffer with HTML markup.
 *
 * @param *buffer The string to parse.
 * @param length The length of the string to parse.
 * @param count Integer flag specifying whether or not to count lines. If yes,
 *   uses the Ragel machine optimized for counting. Otherwise uses the Ragel
 *   machine optimized for returning entity positions.
 * @param *callback Callback function. If count is set, callback is called for
 *   every line of code, comment, or blank with 'lcode', 'lcomment', and
 *   'lblank' respectively. Otherwise callback is called for each entity found.
 */
void parse_html(char *buffer, int length, int count,
  void (*callback) (const char *lang, const char *entity, int start, int end)
  ) {
  init

  %% write init;
  cs = (count) ? html_en_html_line : html_en_html_entity;
  %% write exec;

  // if no newline at EOF; callback contents of last line
  if (count) { process_last_line(HTML_LANG) }
}

#endif

/*****************************************************************************/