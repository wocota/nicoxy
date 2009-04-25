WINDOWS = false

require './http'
require './api'
require './cache'
require 'kconv' if WINDOWS

class Proxy 
  def initialize(conf)
    # check config
    unless File.directory?(conf[:cache_folder])
      str = "Error!: invalid folder name '#{conf[:cache_folder]}'"
      puts WINDOWS ? str.tosjis : str
      return
    end
    unless File.directory?(conf[:local_folder])
      str = "Error!: invalid folder name '#{conf[:local_folder]}'"
      puts WINDOWS ? str.tosjis : str
      return
    end
    unless File.file?(conf[:ng_word_file])
      str =  "Error!: invalid file name '#{conf[:ng_word_file]}'"
      puts WINDOWS ? str.tosjis : str
      return
    end
    @ng_words = load_filter(conf[:ng_word_file])
    @dir = conf[:cache_folder]
    @port = conf[:port]
    @local = conf[:local_folder]
    @wrapper = conf[:flv_wrapper]
    run
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
  def run
    str = "Port:#{@port}\nCache Folder:#{@dir}\nNG Word:#{@ng_words}"
    puts WINDOWS ? str.tosjis : str
    puts "server is started"
    puts "-----------------"
    gs = TCPServer.open(@port)
    while true
      Thread.start(gs.accept) {|browser|
        #print(browser, " is accepted\n")
        cache = Cache.new(@dir)
        request = HttpRequest.new(browser)
        server = TCPSocket.new(request.uri.host, request.uri.port)
        response = HttpResponse.new(server)
        #p request.uri.to_s #debug
        case request.uri.to_s
        when /smile-.*?\.nicovideo.\jp\/smile\?(.)=(\d*)\.\d*(low)?/
          video_id = ($1 == 's' ? 'nm' : 'sm') + $2
          low_mode = ($3 == 'low') ? true : false
          
          if cache_file = cache.find(video_id) or low_mode && cache_file = cache.find("#{video_id}low") # find cache
            request.body
            browser << "HTTP/1.1 200 OK\r\nContent-Type: #{cache_file.mime_type}\r\nContent-Disposition: inline; filename=\"smile.#{cache_file.extname}\"\r\nContent-Length: #{cache_file.size}\r\n"
            browser << "\r\n"
            browser << cache_file.read
          else
            request.header.delete('Range'); request.header.delete('If-Range'); # interim fix: disable http resume
            server << request.header << "\r\n" << request.body 
            response.header{|l| browser << l } 
            browser << "\r\n"

            video = Nicovideo.new(video_id)
            extension = (response.header['Content-Type'] =~ /video\/(\S*?)$/) ? $1 : 'swf'
            filename = "#{video_id}#{low_mode ? 'low' : ''}_#{video.title}.#{extension}"
            cache.save(filename) {|f|
              response.body do |l|
                f << l
                browser << l
              end
            }
          end
        when /msg\.nicovideo\.jp\/\d+\/api/
          # disable gzip request
          request.header.delete('Accept-Encoding')
          # send request_header to server
          server << request.header << "\r\n" << request.body
          # filter
          response.body.gsub!(/(<chat.*?>)[^<]*(#{@ng_words})[^<]*(<\/chat>)/u, '\1\3') if @ng_words.length > 0
          response.header['Content-length'] = "#{response.body.size}"
          # send browser
          browser << response.header << "\r\n" << response.body
        when /www\.nicovideo\.jp\/cache\/flvlist/
          request.body
          puts 'access flvlist'
          res = "# my cache\n" + cache.list
          browser << "HTTP/1.1 200 OK\r\nContent-Length: #{res.size}\r\n"
          browser << "\r\n"
          browser << res
        when /www\.nicovideo\.jp\/cache\/(\S{2}\d+(?:low)?)\./
          request.body
          cache_file = cache.find($1)
          browser << "HTTP/1.1 200 OK\r\nContent-Type: #{cache_file.mime_type}\r\nContent-Disposition: inline; filename=\"smile.#{cache_file.extname}\"\r\nContent-Leng\
th: #{cache_file.size}\r\n"
          browser << "\r\n"
          browser << cache_file.read
        when /www\.nicovideo\.jp\/local\/([^\?]+)/
          request.body
          puts "access #{$1}"
          file = LocalFile.new(@local, $1)
          browser << "HTTP/1.1 200 OK\r\nContent-Type: #{file.mime_type}\r\nContent-Length: #{file.size}\r\n"
          browser << "\r\n"
          browser << file.read
        when /www\.nicovideo\.jp\/watch/
          request.header.delete('Accept-Encoding')
          server << request.header << "\r\n" << request.body
          response.body.gsub!(/swf\/nicoplayer.swf/u, 'local/flvplayer_wrapper.swf') if @wrapper
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
