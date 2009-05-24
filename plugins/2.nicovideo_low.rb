class Nicovideo_low < Nicovideo
  def uri_match_to?(uri)
    @uri = uri
    if @uri =~ /smile-.*?\.nicovideo\.jp\/smile\?([a-z])=(\d*)\.\d*low$/
      @smile, @video_id = $1, $2
    end
  end
  def id
    @video_id + 'low'
  end
  def cache_find
    Dir.entries($conf[:cache_dir]).each do |f|
      return "#{$conf[:cache_dir]}/#{f}" if f =~  /^#{prefix}#{@video_id}_/
    end
    Dir.entries($conf[:cache_dir]).each do |f|
      return "#{$conf[:cache_dir]}/#{f}" if f =~  /^#{prefix}#{id}_/
    end
    false
  end
end

Nicovideo_low.new
