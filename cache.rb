class Cache 
  def initialize(dir)
    @dir = dir
  end
  def find(cache_id)
    Dir.foreach(@dir) { |f|
      if /^#{cache_id}_/ =~ f
        str = "using cache: #{f}"
        puts WINDOWS ? str.tosjis : str
        return LocalFile.new(@dir, f)
      end
    }
    str = "no cached: #{cache_id}"
    puts WINDOWS ? str.tosjis : str
    nil
  end
  def list
    ret = ''
    Dir.foreach(@dir) { |f|
      ret << "#{$1}#{$2} " if /^(\S{2}\d+(?:low)?)_.*(\.\S*?)$/ =~ f
    }
    ret
  end
  def save(filename)
    str = "#{@dir}/tmp.#{filename}"
    File.open(WINDOWS ? str.tosjis : str, 'wb') {|f|
      yield f
    }
    if WINDOWS
      File.rename("#{@dir}/tmp.#{filename}".tosjis, "#{@dir}/#{filename}".tosjis)
    else
      File.rename("#{@dir}/tmp.#{filename}", "#{@dir}/#{filename}")
    end
    str = "cached: #{filename}"
    puts WINDOWS ? str.tosjis : str
  end
end

class LocalFile
  def initialize(dir, name)
    @dir, @name = dir, name
    @file_path = "#{dir}/#{name}"
  end
  def size
    File.size(@file_path)
  end
  def to_s
    @file_path
  end
  def extname
    $1 if @name =~ /\.(\S*?)$/
  end
  def mime_type
    mime_types = {
      'js' => 'application/x-javascript',
      'swf' => 'application/x-shockwave-flash',
      'flv' => 'video/flv',
      'mp4' => 'video/mp4'
    }
    type = mime_types[extname()]
    type ? type : 'plain/text'
  end
  def read
    File.open(@file_path, 'rb') {|f|
      file = f.read
    }
  end
end
