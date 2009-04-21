WINDOWS = false

require './http'
require './api'
require 'stringio'
require 'zlib'
require 'kconv' if WINDOWS

class Proxy 
  def initialize(conf)
    # check config
    unless File.directory?(conf[:cache_folder])
      str = "Error!: invalid folder name '#{conf[:cache_folder]}'"
      puts WINDOWS ? str.tosjis : str
      return
    end
    unless File.file?(conf[:ng_word_file])
      str =  "Error!: invalid file name '#{conf[:ng_word_file]}'"
      puts WINDOWS ? str.tosjis : str
      return
    end
    @ng_word = load_filter(conf[:ng_word_file])
    # show congig
    str = "Port:#{conf[:port]}\nCache Folder:#{conf[:cache_folder]}\nNG Word:#{@ng_word}"
    puts WINDOWS ? str.tosjis : str
    Dir::chdir(conf[:cache_folder])
    run(conf[:port])
  end
  def check_cache(cache_id)
    Dir.foreach('.') { |f|
      if /^#{cache_id}_/ =~ f
        str = "using cache: #{f}"
        puts WINDOWS ? str.tosjis : str
        return f
      end
    }
    str = "no cached: #{cache_id}"
    puts WINDOWS ? str.tosjis : str
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
        when /smile-.*?\.nicovideo.\jp\/smile\?(.)=(\d*)\.\d*(\S*)/
          video_id = ($1 == 's' ? 'nm' : 'sm') + $2
          low_mode = ($3 == 'low') ? true : false
          
          if cache_file = check_cache(video_id) or low_mode && cache_file = check_cache("#{video_id}low") # find cache
            file_size = File.size(cache_file)
            file_type = $1 if cache_file =~ /\.(\S*?)$/
            content_type = file_type == 'swf' ? 'application/x-shockwave-flash' : "video/#{file_type}"
            browser << "HTTP/1.1 200 OK\r\nContent-Type: #{content_type}\r\nContent-Disposition: inline; filename=\"smile.#{file_type}\"\r\nCache-Control: max-age=144000\r\nContent-Length: #{file_size}\r\n"
            browser << "\r\n"
            File.open(cache_file, 'rb') {|f|
              browser << f.read
            }
          else
            video = Nicovideo.new(video_id)
            title =  video.title
            
            request.header.delete('Range'); request.header.delete('If-Range'); # interim fix: disable http resume
            server << request.header << "\r\n" << request.body 
            response.header do |l|
              browser << l 
            end
            browser << "\r\n"
            #p request.header # debug
            #p response.header # debug
            
            # flv mp4 swf
            extension = (response.header['Content-Type'] =~ /video\/(\S*?)$/) ? $1 : 'swf'
            filename = "#{video_id}#{low_mode ? 'low' : ''}_#{title}.#{extension}"
            # send response_body to browser. save file
            str = "tmp.#{filename}"
            File.open(WINDOWS ? str.tosjis : str, 'wb') {|f|
              response.body do |l|
                f << l
                browser << l
              end
            }
            if WINDOWS
              File.rename("tmp.#{filename}".tosjis, "#{filename}".tosjis)
            else
              File.rename("tmp.#{filename}", "#{filename}")
            end
            str = "cached: #{filename}"
            puts WINDOWS ? str.tosjis : str
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
