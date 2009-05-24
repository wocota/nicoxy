WINDOWS = false

require './http'
require './plugin'
require 'kconv' if WINDOWS

class Proxy 
  def initialize(conf)
    # check config
    error = []
    unless File.directory? conf['cache_dir'].to_s
      error << "Error!: invalid folder name #{conf['cache_dir']}"
    end
    unless File.directory? conf['plugin_dir'].to_s
      error << "Error!: invalid folder name #{conf['plugin_dir']}"
    end
    if error.size > 0
      error.each{|m| puts WINDOWS ? m.tosjis : m }
      exit(0)
    end
    $conf = {
      :cache_dir => conf['cache_dir'],
      :plugin_dir => conf['plugin_dir'],
      :port => conf['port'] || 8080
    }
    @video_sites = load_plugins
  end
  def run
    str = "pwd_dir:#{Dir.pwd}\nPort:#{$conf[:port]}\nCache Folder:#{$conf[:cache_dir]}\nPlugin Folder:#{$conf[:plugin_dir]}\nload plugins:#{@video_sites}"
    puts WINDOWS ? str.tosjis : str
    puts "server is started"
    puts "-----------------"
    gs = TCPServer.open($conf[:port])
    while true
      Thread.start(gs.accept) {|browser|
        #print(browser, " is accepted\n")
        request = HttpRequest.new(browser)
        server = TCPSocket.new(request.uri.host, request.uri.port)
        response = HttpResponse.new(server)
        
        uri = request.uri.to_s
        #p uri if uri !~ /(jpg|png|gif)$/
        
        # 配列の要素を複製してから，プログインを見つける
        video = @video_sites.map{|v| v.dup}.find{|site| site.uri_match_to? uri }
        
        if video
          if video.cached?
            str = 'using cache:' + video.cache_name
            puts WINDOWS ? str.tosjis : str
            request.body
            browser << "HTTP/1.1 200 OK\r\nContent-Type: #{video.cache_mime_type}\r\nContent-Disposition: inline; filename=\"smile.#{video.extension}\"\r\nContent-Length: #{video.cache_size}\r\n"
            browser << "\r\n"
            browser << video.cache_read
          else
            puts 'no cached'
            video.save {|cache|
              # interim fix: disable http resume
              request.header.delete('Range'); request.header.delete('If-Range');
              #p request.header
              server << request.header << "\r\n" << request.body
              #p response.header
              # やっつけリダイレクト用
              if response.status.to_i == 303 and response.header['Location'] =~ %r{http://([^/]+)}
                #p response.status.to_i, response.header['Location']
                req = "GET #{response.header['Location']} HTTP/1.1\r\nUser-Agent: #{response.header['User-Agent']}\r\n"
                server.close
                server = TCPSocket.new($1, 80)
                response = HttpResponse.new(server)
                server << req
                server << "\r\n"
              end
              response.header do |l|
                browser << l
              end
              browser << "\r\n"
              response.body do |l|
                browser << l
                cache << l
              end
            }
            puts 'cached:' + video.cache_name
          end
        else
          # send request_header to server
          server << request.header << "\r\n" << request.body
          # send response to browser
          response.header do |l|
            browser << l
          end
          browser << "\r\n"
          response.body do |l|
            browser << l
          end
        end
                       
        server.close
        #print(browser, " is gone\n")
        browser.close
      }
    end
  end
end
