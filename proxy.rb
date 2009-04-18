require './http'
require './api'
require 'stringio'
require 'zlib'

class Proxy 
  def initialize(conf)
    # check config
    unless File.directory?(conf[:cache_folder])
      puts "Error!: invalid folder name '#{conf[:cache_folder]}'"
      return
    end
    unless File.file?(conf[:ng_word_file])
      puts "Error!: invalid file name '#{conf[:ng_word_file]}'"
      return
    end
    @ng_word = load_filter(conf[:ng_word_file])
    # show congig
    puts "Port:#{conf[:port]}\nCache Folder:#{conf[:cache_folder]}\nNG Word:#{@ng_word}"
    Dir::chdir(conf[:cache_folder])
    run(conf[:port])
  end
  def check_cache(cache_id)
    Dir.foreach('.') { |f|
      if /^#{cache_id}_/ =~ f
        puts "using cache: #{f}"
        return f
      end
    }
    puts "no cached: #{cache_id}"
    nil
  end
  def load_filter(file)
    ret = ""
    File.open(file) {|f|
      ret << (f.gets =~ /^(\S+)$/ ? $1 : '')
      while l = f.gets
        next unless l =~ /^(\S+)$/
        ret << "|" << $1
      end
    }
    ret
  end
  def run(port)
    gs = TCPServer.open(port)
    puts "server is started"
    puts "-----------------"
    while true
      Thread.start(gs.accept) {|browser|
        #print(browser, " is accepted\n")
        
        request = HttpRequest.new(browser)
        server = TCPSocket.new(request.uri.host, request.uri.port)
        response = HttpResponse.new(server)
        #p request.uri.to_s #debug
        case request.uri.to_s
        when /smile-.*?\.nicovideo.\jp\/smile\?.=(\d*)\.\d*(\S*)/
          video_id = $1
          cache_id = "sm#{$1}"
          low_mode = $2 == 'low' ? true : false
          
          if cache_file = check_cache(cache_id) or low_mode && cache_file = check_cache("#{cache_id}low") # find cache
            file_size = File.size(cache_file)
            file_type = $1 if cache_file =~ /\.(\S*?)$/
            browser << "HTTP/1.1 200 OK\r\nContent-Type: video/#{file_type}\r\nContent-Disposition: inline; filename=\"smile.flv\"\r\nCache-Control: max-age=144000\r\nContent-Length: #{file_size}\r\n"
            browser << "\r\n"
            File.open(cache_file) {|f|
              browser << f.read
            }
          else
            video = Nicovideo.new(video_id)
            title =  video.title
              
            server << request.header << "\r\n" << request.body
            response.header do |l|
              browser << l
            end
            browser << "\r\n"
            extension = response.header['Content-Type'] =~ /video\/(\S*?)$/ ? $1 : 'flv'
            filename = "#{cache_id}#{low_mode ? 'low' : ''}_#{title}.#{extension}"
            # send response_body to browser. save file
            File.open("tmp.#{filename}", 'w') {|f|
              response.body do |l|
                f << l
                browser << l
              end
            }
            File.rename("tmp.#{filename}", "#{filename}")
            puts "cached: #{filename}"
          end
        when /msg\.nicovideo\.jp/
          # send request_header to server
          server << request.header << "\r\n" << request.body
          # decode if gzip
          if response.header['Content-Encoding'] == 'gzip'
            Zlib::GzipReader.wrap(StringIO.new(response.body)){|gz|
              body = gz.read
              response.header['Content-Encoding'] = "identity"
              response.body = body
            }
          end
          # filter
          filter = @ng_word
          response.body.gsub!(/(<chat.*?>)[^<]*(#{filter})[^<]*(<\/chat>)/u, '\1\3') if filter.length > 0
          response.header['Content-length'] = "#{response.body.size}"
          
          # send browser
          browser << response.header << "\r\n" << response.body 
        else
          # send request to server
          server << request.header << "\r\n" << request.body 
          # send response_header to browser
          response.header do |l|
            browser << l
          end
          browser << "\r\n"
          # send response_body to browser
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
