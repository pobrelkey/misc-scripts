#!/usr/bin/env ruby

# freshwiki.rb - spin up a simple, ephemeral "wiki" server.
# Written entirely in batteries-included Ruby.
# For personal use on private networks, not for public use.

require 'cgi'
require 'fileutils'
require 'gdbm'
require 'optparse'
require 'rdoc'
require 'webrick'

port = (ENV['FRESHWIKI_PORT'] || 8484).to_i
db_file = ENV['FRESHWIKI_DB'] || "#{ENV['HOME']}/.local/share/freshwiki/default"
addr = ENV['FRESHWIKI_ADDR'] || '0.0.0.0'
open_browser = true

OptionParser.new do |opts|
  opts.on('-n NAME', '--name NAME',  'Store data in ~/.local/share/freshwiki/NAME') {|fn| db_file = "#{ENV['HOME']}/.local/share/freshwiki/#{fn}" }
  opts.on('-e',      '--ephemeral',  'Ephemeral wiki, don\'t save to disk') {|fn| db_file = nil }
  opts.on('-f FILE', '--file FILE',  "Store data in FILE (default: #{db_file})") {|fn| db_file = fn }
  opts.on('-l',      '--localhost',  "Bind to 127.0.0.1 (default: #{addr})") { addr = '127.0.0.1' } 
  opts.on('-B',      '--no-browser', 'Don\'t open wiki in browser') { open_browser = false } 
  opts.on('-p PORT', '--port PORT',  "Set port number (default: #{port})") {|p| port = p }
  opts.on('-h',      '--help',       'Print help') { puts opts; exit }
end.parse!

server = WEBrick::HTTPServer.new(:BindAddress=>addr, :Port=>port)

db = Hash.new
if db_file =~ /\S/
  FileUtils.mkdir_p(File.dirname(db_file))
  db = GDBM.open(db_file, 0644, GDBM::WRCREAT)
end

TO_HTML = RDoc::Markup::ToHtml.new(RDoc::Options.new, nil)
def md_to_html(md)
  return RDoc::Markdown.parse(md).accept(TO_HTML)
end

def html_resp(resp, title, body, footeritem='')
  raw_body = <<-"__TMPL__"
    <html><head>
    <title>#{CGI.escape_html(title)}</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <style>#page { margin: 1em; word-wrap: break-word; }</style>
    </head><body>
    #{body}
    <hr />
    <i>FreshWiki &#8226; <a href="/">Home</a> &#8226; <a href="/_all">All Pages</a> &#8226; <a href="/_search">Search</a>
    #{footeritem =~ /\S/ ? (' &#8226; ' + footeritem) : ''}
    </i>
    </body></html>
  __TMPL__
  resp.content_type = 'text/html; charset=UTF-8'
  resp.body = raw_body.encode(Encoding::UTF_8)
end

server.mount_proc('/') do |req, res|
  query_string = CGI.parse(req.query_string || '')
  path = (req.path =~ /^\/?(\w[^\/]*)/ ? $1 : 'Home')

  if path == '_search'
    terms = (query_string['q'] || []).first
    page = '<h1><i>Search</i></h1><form method="GET">' +
      "<p><input size=\"30\" name=\"q\" type=\"text\" value=\"#{CGI.escape(terms || '')}\"/>" +
      '<input type="submit" value="Search" /></p></form>'
    if terms =~ /\S/
      rx = Regexp.compile(terms)
      results = db.each_pair
        .collect{|k,v| [k, v.scan(rx)] }
        .select{|k,vv| vv.size > 0}
        .sort{|a,b| [-a.last.size, a.first] <=> [-b.last.size, b.first] }
      page += results.empty? ? '<i>No results</i>' : 
        ('<ul>' + 
          results.collect{|k,vv| 
            "<li><b><a href=\"/#{CGI.escape(k)}\">#{CGI.escape_html(k)}</a></b><ul>" +
            vv.sort.uniq.collect{|v| '<li><tt>' + CGI.escape_html(v.is_a?(String) ? v : v.inspect) + '</tt></li>' } + 
            '</ul></li>' } + 
          '</ul>') 
    end
    html_resp(res, 'Search', page)
    
  elsif path == '_all'
    html_resp(res, 'All Pages',
      '<h1><i>All Pages</i></h1><ul>' + 
      db.keys.sort.collect{|k| "<li><a href=\"#{CGI.escape(k)}\">#{CGI.escape_html(k)}</a></li>"}.join + 
      '</ul>')

  elsif query_string['mode'] == %w(links)
    headline = "<h1><i>links to <a href=\"/#{CGI.escape(path)}\">#{CGI.escape_html(path)}</a></i></h1>"
    rx = /<a\b[^>]* href=(["']?)\/?#{Regexp.quote(path)}\1/
    matches = db.each_pair
      .collect{|k,v| k if md_to_html(v) =~ rx }
      .compact.sort
    body = matches.empty? ? '<i>no links</i>' : ('<ul>' + 
      matches.collect{|x| "<li><a href=\"/#{CGI.escape(x)}\">#{CGI.escape_html(x)}</a></li>" }.join + '</ul>')
    html_resp(res, "Links to #{path}", headline + body)

  else
    post_args = req.request_method.upcase == 'POST' ? CGI.parse(req.body) : {}
    md = (post_args['text'] || [db[path]]).first

    if query_string['mode'] == %w(edit) || db[path].nil?
      if req.request_method.upcase != 'POST' || post_args['action'] == %w(Preview)
        headline = "<h1><i>editing <a href=\"/#{CGI.escape(path)}\">#{CGI.escape_html(path)}</a></i></h1>"
        body = '<form action="?mode=edit" method="POST"><p><textarea name="text" rows="15" cols="60">' + 
          CGI.escape_html(md || '') +
          '</textarea><br />' +
          '<input type="submit" name="action" value="Preview" />' +
          '<input type="submit" name="action" value="Submit" />' +
          '</p></form>'
        if post_args['action'] == %w(Preview)
          body += "<hr /><div>#{md_to_html(md)}</div>"
        end
        html_resp(res, "Editing #{path}", headline + body, " &#8282; <a href=\"?mode=links\">Backlinks</a>")
      else
        db[path] = md
        res.set_redirect(WEBrick::HTTPStatus::Found,'/'+path)
      end
    else
      headline = "<h1><a href=\"/#{CGI.escape(path)}?mode=edit\">#{CGI.escape_html(path)}</a></h1>"
      body = "<div>#{md_to_html(md)}</div>"
      html_resp(res, path, headline + body, " &#8282; <a href=\"?mode=links\">Backlinks</a>")
    end
  end
  
end

trap 'INT' do 
  server.shutdown
  db.close if db.is_a?(GDBM)
end

fork { sleep 1; system('xdg-open', "http://#{(addr=='0.0.0.0')?'127.0.0.1':addr}:#{port}/") } if open_browser

server.start
