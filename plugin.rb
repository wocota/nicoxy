class VideoSitePlugin
  def save
    name = "#{prefix}#{id}_#{title ? title : 'no_title'}.#{extension}".gsub(/[\\\/\,\;\:\*\?\"\<\>\|]/,'_')
    path = "#{$conf[:cache_dir]}/#{name}"
    tmp = "#{$conf[:cache_dir]}/tmp.#{name}"
    File.open(WINDOWS ? tmp.tosjis : tmp, 'wb') {|f| yield f}
    if WINDOWS
      File.rename(tmp.tosjis, path.tosjis)
    else
      File.rename(tmp, path)
    end
  end
  def cache_find
    Dir.entries($conf[:cache_dir]).each do |f|
      return "#{$conf[:cache_dir]}/#{f}" if f =~ /^#{prefix}#{id}_/
    end
    false
  end
  def cached?
    @cache_path = cache_find
    @cache_path ? true : false
  end
  def cache_name
    if cached?
      File.basename(@cache_path)
    end
  end
  def cache_read
    if cached?
      File.open(WINDOWS ? @cache_path.tosjis : @cache_path, 'rb') {|f|
        f.read
      }
    end
  end
  def cache_size
    if cached?
      File.size(WINDOWS ? @cache_path.tosjis : @cache_path)
    end
  end
  def cache_mime_type
    mime_types = {
      'js' => 'application/x-javascript',
      'swf' => 'application/x-shockwave-flash',
      'flv' => 'video/flv',
      'mp4' => 'video/mp4'
    }
    mime_types.default = 'plain/text'
    mime_types[extension]
  end
end

def load_plugins
  sites = []
  pd = $conf[:plugin_dir]
  Dir.entries(pd).sort.each do |f|
    next if f !~ /\.rb$/
    File.open("#{pd}/#{f}") {|file|
      tmp = eval(file.read)
      sites << tmp if tmp.kind_of? VideoSitePlugin
    }
  end
  sites
end
