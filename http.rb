require 'socket'
require 'uri'

class HttpHeader < String
  def [](key)
    return $1 if self.scan(/^#{key.strip}:\s*(.*?)\s*\r?\n/)
    nil
  end
  def []=(key, str)
    key.strip!; str.strip!
    if not self.gsub!(/^#{key}:\s*.*?\s*\r?\n/, "#{key}: #{str}\r\n")
      self << "#{key}: #{str}\r\n"
    end
    str
  end
  def delete(key)
    return $1 if self.gsub!(/^#{key.strip}:\s*(.*?)\s*\r?\n/, '')
    nil
  end
end

class HttpRequest
  def initialize(socket)
    @socket = socket
  end
  def header
    if not defined?(@header)
      @header      = HttpHeader.new
      request_line = @socket.gets
      l = request_line.gsub(URI.regexp) do |s|
        @uri = URI s
        s = @uri.request_uri
      end
      begin
        break if l =~ /\A\r?\n/
        @header << l
        yield l if block_given?
      end while l = @socket.gets
    elsif block_given?
      @header.each_line do |l|
        yield l
      end
    end
    @header
  end
  def body
    if not defined?(@body)
      @body = ''
      if method == 'POST' and con_len = header['Content-length']
        total_len, body_len = 0, con_len.to_i
        while total_len < body_len and l = @socket.readpartial(4096)
          @body << l
          yield l if block_given?
          total_len += l.size
        end
      end
    elsif block_given?
      @body.each_line do |l|
        yield l
      end
    end
    @body
  end
  def uri
    header unless defined?(@uri)
    @uri
  end
  def parse_request_line
    if header =~ /\A(\S+)\s+(\S+)(?:\s+HTTP\/(\d+\.\d+))?\r?\n/mo
      @method, @path, @http_version = $1, $2, ($3 ? $3 : "0.9")
    end
  end
  def method
    parse_request_line unless defined?(@method)
    @method
  end
  def path
    parse_request_line unless defined?(@path)
    @path
  end
  def http_version
    parse_request_line unless defined?(@http_version)
    @http_version
  end
end

class HttpResponse
  def initialize(socket)
    @socket = socket
  end
  def header
    if not defined?(@header)
      @header = HttpHeader.new
      while l = @socket.gets
        break if l =~ /\A\r?\n/
        @header << l
        yield l if block_given?
      end
    elsif block_given?
      @header.each_line do |l|
        yield l
      end
    end
    @header
  end
  def header= (str)
    @header = str.to_s
  end
  def body
    if not defined?(@body)
      @body = ''
      if status.to_i == 304 or status.to_i == 303
      elsif body_len = header['Content-Length']
        total_len, max_len = 0, body_len.to_i
        while total_len < max_len and l = @socket.readpartial(4096)
          @body << l
          yield l if block_given?
          total_len += l.size
        end
      else
        while l = @socket.gets
          @body << l
          yield l if block_given?
        end
      end
    elsif block_given?
      @body.each_line do |l|
        yield l
      end
    end
    @body
  end
  def body= (str)
    @body = str.to_s
  end
  def parse_response_line
    if header =~ /\AHTTP\/(\d\.\d)\s+(\d+)/mo
      @http_version, @status = ($1 ? $1 : "0.9"), $2
    end
  end
  def http_version
    parse_response_line unless defined?(@http_version)
    @http_version
  end
  def status
    parse_response_line unless defined?(@status)
    @status
  end
end

