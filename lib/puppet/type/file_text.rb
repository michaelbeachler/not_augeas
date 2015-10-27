Puppet::Type.newtype(:file_text) do

  desc <<-EOT
    Put Description here with usage...

  EOT

  file_text_changes = Hash.new

  newparam(:name, :namevar => true) do
    desc "Resource name"
  end

  newparam(:tag) do
    desc "Tag reference to collect all concat_fragment's with the same tag"
  end

  newparam(:match) do
    desc 'An optional ruby regular expression to run against lines matching' +
         ' the search attribute within the file.' + 
         ' If BOTH the search string and match ruby regular expression is found,' +
         ' we replace the search text.'
  end

  newparam(:search) do
    desc 'The text to be replaced within the file.  Can be used in conjunction with the' +
         'match attribute.'
  end

  newparam(:replace) do
    desc 'The text to replace the search attribute within the file.'
  end

  newparam(:backup) do
    desc 'Whether (and how) file content should be backed up before being replaced.'
    defaultto do
      'puppet'
    end
  end

  newparam(:file_content_replace) do
    desc 'Whether to replace a file or symlink that already exists on the local system but whose content doesn’t match what the content attribute specifies.'
    defaultto do
      true
    end
  end

  newparam(:file_content_ensure) do
    desc 'Whether the file should exist, and if so what kind of file it should be.'
    defaultto do
      'file'
    end
  end

  newparam(:path) do
    desc 'The file Puppet will ensure contains the text specified by the text parameter.'
    defaultto do
      resource.value(:name)
    end
    validate do |value|
      unless (Puppet.features.posix? and value =~ /^\//) or (Puppet.features.microsoft_windows? and (value =~ /^.:\// or value =~ /^\/\/[^\/]+\/[^\/]+/))
        raise(Puppet::Error, "File paths must be fully qualified, not '#{value}'")
      end
    end
  end

  validate do
    unless self[:search] and self[:path]
      raise(Puppet::Error, "Both search and path are required attributes")
    end
  end

  def generate
    catalog.resources.select do |r|
      if r.is_a?(Puppet::Type.type(:file_text)) && r[:tag] == self[:tag]
        Puppet.debug "not_augeas(autorequire) - #{r} Resources Path: #{r[:path]}"
        if r[:match]
          Puppet.debug "not_augeas(autorequire) - #{r} Resources Match: #{r[:match]}"
        end
        Puppet.debug "not_augeas(autorequire) - #{r} Resources Search: #{r[:search]}"
        Puppet.debug "not_augeas(autorequire) - #{r} Resources Replace: #{r[:replace]}"
      end
    end

    # This sub is magically called ...
    Puppet.debug "not_augeas(generate) - I'm in this sub"
    handle_type = handle_type()
    Puppet.debug "not_augeas(generate) - Handle Type: #{handle_type}"
    file_opts = Hash.new
    if handle_type == "handle_search_without_match"
      Puppet.debug "not_augeas(generate) - Gathering File Options For Handle Type: #{handle_type}"
      file_opts = handle_search_without_match()
    elsif handle_type == "handle_search_with_match"
      Puppet.debug "not_augeas(generate) - Gathering File Options For Handle Type: #{handle_type}"
      file_opts = handle_search_with_match()
    else
      Puppet.debug "not_augeas(generate) - Handle Type Not Found"
    end

    if handle_type and file_opts
      Puppet.debug "not_augeas(generate) - File Options Inspect: #{file_opts.inspect}"
      Puppet::Type.type(:file).new(file_opts)
    end

    # Puppet::Type.type(:file).new :path => self[:path], :backup => 'puppet', :ensure => 'file', :content => "This is a test"

  end

  def handle_type
    Puppet.debug "not_augeas(handle_type) - I'm in this sub"
    handle = nil

    if self[:match]
      if self[:replace] and count_matches(match_search, match_regex) > 0
        handle = "handle_search_with_match"
        Puppet.debug "not_augeas(handle_type) - Setting handle to #{handle}"
      end
    elsif self[:replace] and count_matches(match_search, match_regex) > 0
        handle = "handle_search_without_match"
        Puppet.debug "not_augeas(handle_type) - Setting handle to #{handle}"
    end
    return handle
  end

  def lines
    @lines ||= File.readlines(self[:path])
  end

  def match_regex
    self[:match] ? Regexp.new(self[:match]) : nil
  end

  def match_search
    self[:search] ? Regexp.new(self[:search]) : nil
  end

  def count_matches(search, regex)
    Puppet.debug "not_augeas(count_matches) - I'm in this sub"
    my_count = 0

    if regex
      Puppet.debug "not_augeas(count_matches) - :search defined #{search}, :match defined #{regex}"
      my_count = lines.select{|l| l.match(search) and l.match(regex)}.size
    elsif search
      Puppet.debug "not_augeas(count_matches) - :search defined #{search}"
      my_count = lines.select{|l| l.match(search)}.size
    end
    Puppet.debug "not_augeas(count_matches) - Count Matches: #{my_count.to_s}"
    return my_count
  end

  def handle_search_without_match()
    Puppet.debug "not_augeas(handle_search_without_match) - I'm in this sub"

    file_contents = File.open(self[:path], 'r').read
    file_contents.gsub!(/#{self[:search]}/, "#{self[:replace]}")

    file_opts = Hash.new
    file_opts[:name] = self[:name]
    Puppet.debug "not_augeas(handle_search_without_match) - :name => #{file_opts[:name].inspect}"

    file_opts[:content] = file_contents.split('\n')
    Puppet.debug "not_augeas(handle_search_without_match) - :content => #{file_opts[:content].inspect}"

    file_opts[:replace] = self[:file_content_replace]
    Puppet.debug "not_augeas(handle_search_without_match) - :replace => #{file_opts[:replace].inspect}"

    file_opts[:ensure] = self[:file_content_ensure]
    Puppet.debug "not_augeas(handle_search_without_match) - :ensure => #{file_opts[:ensure].inspect}"

    file_opts[:path] = self[:path]
    Puppet.debug "not_augeas(handle_search_without_match) - :path => #{file_opts[:path].inspect}"

    file_opts[:backup] = self[:backup]
    Puppet.debug "not_augeas(handle_search_without_match) - :backup => #{file_opts[:backup].inspect}"

    file_opts[:backup] = self[:backup]
    Puppet.debug "not_augeas(handle_search_with_match) - :backup => #{file_opts[:backup].inspect}"

    Puppet.debug "not_augeas(handle_search_without_match) - file_opts => #{file_opts.inspect}"

    return file_opts
  end

  def handle_search_with_match()
    Puppet.debug "not_augeas(handle_search_with_match) - I'm in this sub"

    new_file_contents = Array.new
    lines.each do |line_content|
      if "#{line_content}" =~ /#{self[:match]}/
        line_content.gsub!(/#{self[:search]}/, "#{self[:replace]}")
        new_file_contents << line_content
      else
        new_file_contents << line_content
      end
    end
    file_contents = new_file_contents.join('')

    file_opts = Hash.new
    file_opts[:name] = self[:name]
    Puppet.debug "not_augeas(handle_search_with_match) - :name => #{file_opts[:name].inspect}"

    file_opts[:content] = file_contents.split('\n')
    Puppet.debug "not_augeas(handle_search_with_match) - :content => #{file_opts[:content].inspect}"

    file_opts[:replace] = self[:file_content_replace]
    Puppet.debug "not_augeas(handle_search_with_match) - :replace => #{file_opts[:replace].inspect}"

    file_opts[:ensure] = self[:file_content_ensure]
    Puppet.debug "not_augeas(handle_search_with_match) - :ensure => #{file_opts[:ensure].inspect}"

    file_opts[:path] = self[:path]
    Puppet.debug "not_augeas(handle_search_with_match) - :path => #{file_opts[:path].inspect}"

    file_opts[:backup] = self[:backup]
    Puppet.debug "not_augeas(handle_search_with_match) - :backup => #{file_opts[:backup].inspect}"

    Puppet.debug "not_augeas(handle_search_with_match) - file_opts => #{file_opts.inspect}"

    return file_opts
  end

end
