# -*- coding: utf-8; mode: ruby; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2
# -*- vim:fenc=utf-8:filetype=ruby:et:sw=2:ts=2:sts=2

# Provides content escaping helpers.
module GitCommitNotifier::EscapeHelper
  # Expand tabs into spaces.
  # @param [String] s Text to be expanded.
  # @param [FixNum] tabWidth One tab indentation (in count of spaces).
  # @return [String] Expanded text.
  def expand_tabs(s, tabWidth)
    delta = 0
    s.gsub(/\t/) do |m|
      add = tabWidth - (delta + $~.offset(0)[0]) % tabWidth
      delta += add - 1
      " " * add
    end
  end

  # Escapes expanded content using CGI.escapeHTML and {#expand_tabs}.
  # @param [String] s Text to be expanded and extended.
  # @return [String] Escaped and expanded text.
  # @see #expand_tabs
  def escape_content(s)
    CGI.escapeHTML(expand_tabs(s, 4)).gsub(" ", "&nbsp;")
  end

  def decode_escaped_filename( filename )
    filename.gsub( /\\\d\d\d\\\d\d\d/ ) { |match|
      mb_char_code  = match.split( '\\' )[ 1, 2 ]
      mb_char_code.map! { |x| x.oct }
      mb_char_code.pack( 'C*' ).force_encoding( 'UTF-8')
    }
  end
end
