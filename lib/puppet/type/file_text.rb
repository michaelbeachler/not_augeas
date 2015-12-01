Puppet::Type.newtype(:file_text) do

  desc <<-EOT
    Put Description here with usage...

  EOT

  file_text_changes = Hash.new

  newparam(:name, :namevar => true) do
    desc "Resource name"
  end

  newparam(:tag) do
    desc "Tag reference to collect all file_text resources with the same tag"
    defaultto do
      resource.value(:path)
    end
  end

  newparam(:match) do
    desc 'An optional ruby regular expression to run against lines matching' +
         ' the search attribute within the file.' +
         ' If BOTH the search string and match ruby regular expression is found,' +
         ' we replace the search text.' +
         'Note: BOTH match and nomatch expressions are honored if specified.'
  end

  newparam(:nomatch) do
    desc 'An optional ruby regular expression to run against lines matching' +
         ' the search attribute within the file.' +
         ' If the search string IS found and nomatch ruby regular expression is NOT found,' +
         ' we replace the search text.'
         'Note: BOTH match and nomatch expressions are honored if specified.'
  end

  newparam(:search) do
    desc 'The text to be replaced within the file.  Can be used in conjunction with the' +
         'match and/or nomatch attributes.'
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

  newparam(:order) do
    desc 'The order to apply the changes.  Sometimes order matters.'
  end

  newparam(:file_content_replace) do
    desc 'Whether to replace a file or symlink that already exists on the local system' +
         'but whose content does not match what the content attribute specifies.'
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
    Puppet.debug "not_augeas(generate) - I'm in this sub"

    file_opts = Hash.new

    update_file = 0
    hash_has_order = 0

    not_augeas_catalog_hash = Hash.new

    catalog.resources.select do |r|
      if r.is_a?(Puppet::Type.type(:file_text)) && r[:tag] == self[:tag]
        current_name = r[:name]
        if not not_augeas_catalog_hash[current_name]
          not_augeas_catalog_hash[current_name] = Hash.new
          not_augeas_catalog_hash[current_name].merge!(r)
        
          Puppet.debug "not_augeas(generate :: catalog_resources) - #{r} Resources Tag: #{r[:tag]}"
          Puppet.debug "not_augeas(generate :: catalog_resources) - #{r} Resources Path: #{r[:path]}"
          if r[:match]
            Puppet.debug "not_augeas(generate :: catalog_resources) - #{r} Resources Match: #{r[:match]}"
          end
          if r[:nomatch]
            Puppet.debug "not_augeas(generate :: catalog_resources) - #{r} Resources Nomatch: #{r[:nomatch]}"
          end
          if r[:order]
            Puppet.debug "not_augeas(generate :: catalog_resources) - #{r} Resources Order: #{r[:order]}"
            hash_has_order = 1
          end
          Puppet.debug "not_augeas(generate :: catalog_resources) - #{r} Resources Search: #{r[:search]}"
          Puppet.debug "not_augeas(generate :: catalog_resources) - #{r} Resources Replace: #{r[:replace]}"
        end
      end
    end

    if hash_has_order == 1
      Puppet.debug "not_augeas(generate) - not_augeas_catalog_hash: Order Detected.  Sorting Hash"
      not_augeas_catalog_hash = not_augeas_catalog_hash.sort_by{ |key, value| value[:order] }
    end

    Puppet.debug "not_augeas(generate) - not_augeas_catalog_hash: #{not_augeas_catalog_hash.inspect}"

    not_augeas_catalog_hash.each do |key, value|
      if file_opts.empty?
        file_opts = initial_file_opts
      end

      Puppet.debug "not_augeas(generate) - Catalog Resource Record: #{value}"
      r_handle_type = handle_type(value)
      Puppet.debug "not_augeas(generate) - Handle Type: #{r_handle_type}"
      if r_handle_type == "handle_search_without_match"
        Puppet.debug "not_augeas(generate) - Gathering File Options For Handle Type: #{r_handle_type}"
        file_opts = handle_search_without_match(value, file_opts)
      elsif r_handle_type == "handle_search_with_match"
        Puppet.debug "not_augeas(generate) - Gathering File Options For Handle Type: #{r_handle_type}"
        file_opts = handle_search_with_match(value, file_opts)
      else
        Puppet.debug "not_augeas(generate) - Handle Type Not Found"
      end

      if r_handle_type and file_opts
        update_file = 1
      end

      # TEST - Puppet::Type.type(:file).new :path => self[:path], :backup => 'puppet', :ensure => 'file', :content => "This is a test"
    end

    if update_file == 1
      Puppet.debug "not_augeas(generate) - Updating File With Options: #{file_opts.inspect}"
      file_opts[:name] = file_opts[:path]
      Puppet.debug "not_augeas(generate) - File Declaration: #{file_opts[:name]}"
      Puppet::Type.type(:file).new(file_opts)
    end

  end

  def handle_type(r=nil)
    Puppet.debug "not_augeas(handle_type) - I'm in this sub"
    handle = nil

    if r[:match]
      if r[:replace] and count_matches(match_search(r), match_regex(r), nil) > 0
        handle = "handle_search_with_match"
        Puppet.debug "not_augeas(handle_type) - Setting handle to #{handle}"
      end
    elsif r[:nomatch]
      if r[:replace] and count_matches(match_search(r), nil, nomatch_regex(r)) > 0
        handle = "handle_search_with_match"
        Puppet.debug "not_augeas(handle_type) - Setting handle to #{handle}"
      end
    elsif r[:replace] and count_matches(match_search(r), match_regex(r), nil) > 0
        handle = "handle_search_without_match"
        Puppet.debug "not_augeas(handle_type) - Setting handle to #{handle}"
    end
    return handle
  end

  def lines
    @lines ||= File.readlines(self[:path])
  end

  def match_regex(r=nil)
    r[:match] ? Regexp.new(r[:match]) : nil
  end

  def nomatch_regex(r=nil)
    r[:nomatch] ? Regexp.new(r[:nomatch]) : nil
  end

  def match_search(r=nil)
    r[:search] ? Regexp.new(r[:search]) : nil
  end

  def count_matches(search=nil, regex=nil, noregex=nil)
    Puppet.debug "not_augeas(count_matches) - I'm in this sub"
    my_count = 0

    if regex and noregex
      Puppet.debug "not_augeas(count_matches) - :search defined #{search}, :match defined #{regex}, :nomatch defined #{noregex}"
      my_count = lines.select{|l| l.match(search) and l.match(regex) and not l.match(noregex)}.size
    elsif regex
      Puppet.debug "not_augeas(count_matches) - :search defined #{search}, :match defined #{regex}"
      my_count = lines.select{|l| l.match(search) and l.match(regex)}.size
    elsif noregex
      Puppet.debug "not_augeas(count_matches) - :search defined #{search}, :nomatch defined #{noregex}"
      my_count = lines.select{|l| l.match(search) and not l =~ /#{noregex}/}.size
    elsif search
      Puppet.debug "not_augeas(count_matches) - :search defined #{search}"
      my_count = lines.select{|l| l.match(search)}.size
    end
    Puppet.debug "not_augeas(count_matches) - Count Matches: #{my_count.to_s}"
    return my_count
  end

  def initial_file_opts
    Puppet.debug "not_augeas(initial_file_ops) - Loading File Contents #{self[:path]}"
    file_contents = File.open(self[:path], 'r').read

    file_opts = Hash.new

    if file_contents
      file_opts[:name] = self[:name]
      Puppet.debug "not_augeas(initial_file_ops) - :name => #{file_opts[:name].inspect}"

      file_opts[:content] = file_contents.split('\n')
      Puppet.debug "not_augeas(initial_file_ops) - :content => #{file_opts[:content].inspect}"

      file_opts[:replace] = self[:file_content_replace]
      Puppet.debug "not_augeas(initial_file_ops) - :replace => #{file_opts[:replace].inspect}"

      file_opts[:ensure] = self[:file_content_ensure]
      Puppet.debug "not_augeas(initial_file_ops) - :ensure => #{file_opts[:ensure].inspect}"

      file_opts[:path] = self[:path]
      Puppet.debug "not_augeas(initial_file_ops) - :path => #{file_opts[:path].inspect}"

      file_opts[:backup] = self[:backup]
      Puppet.debug "not_augeas(initial_file_ops) - :backup => #{file_opts[:backup].inspect}"

      Puppet.debug "not_augeas(initial_file_ops) - file_opts => #{file_opts.inspect}"
    end

    return file_opts
  end

  def handle_search_without_match(r=nil, file_opts=nil)
    Puppet.debug "not_augeas(handle_search_without_match) - I'm in this sub"

    if not file_opts.nil?
      new_file_contents = Array.new
      existing_file_contents = Array.new

      if file_opts[:content].is_a?(String)
        existing_file_contents = file_opts[:content].split("\n")
      else
        existing_file_contents = file_opts[:content]
      end

      file_line_count = existing_file_contents.count
      Puppet.debug "not_augeas(handle_search_with_match) - File Line Count => #{file_line_count}"

      existing_file_contents.each do |line_content|
        # Puppet.debug "not_augeas(handle_search_without_match) - Content Line => #{line_content}"
        line_content.gsub!(/#{r[:search]}/, "#{r[:replace]}")
        new_file_contents << line_content
      end
      file_opts[:content] = new_file_contents.join("\n")
      if file_opts[:content] !~ /\n$/
        file_opts[:content] += "\n"
      end

      Puppet.debug "not_augeas(handle_search_without_match) - :content => #{file_opts[:content].inspect}"

      Puppet.debug "not_augeas(handle_search_without_match) - file_opts => #{file_opts.inspect}"
    end

    return file_opts
  end

  def handle_search_with_match(r=nil, file_opts=nil)
    Puppet.debug "not_augeas(handle_search_with_match) - I'm in this sub"

    if not file_opts.nil?
      new_file_contents = Array.new
      existing_file_contents = Array.new

      if file_opts[:content].is_a?(Array)
        if file_opts[:content].count == 1
          existing_file_contents = file_opts[:content][0].split("\n")
        else
          existing_file_contents = file_opts[:content]
        end
      else
        # existing_file_contents = file_opts[:content][0].split("\n")
        existing_file_contents = file_opts[:content].split("\n")
      end

      file_line_count = existing_file_contents.count
      Puppet.debug "not_augeas(handle_search_with_match) - File Line Count => #{file_line_count}"

      existing_file_contents.each do |line_content|
        # Puppet.debug "not_augeas(handle_search_with_match) - Content Line => #{line_content}"
        # Puppet.debug "not_augeas(handle_search_with_match) - Looking For Match => #{r[:match]}"
        if r[:match] and r[:nomatch]
          Puppet.debug "not_augeas(handle_search_with_match) - Entering Match With NoMatch Block"
          if line_content =~ /#{r[:match]}/ and line_content !~ /#{r[:nomatch]}/
            Puppet.debug "not_augeas(handle_search_with_match) - Match With NoMatch Found => #{line_content}"
            line_content.gsub!(/#{r[:search]}/, "#{r[:replace]}")
            new_file_contents << line_content
          else
            new_file_contents << line_content
          end
        elsif r[:match] and not r[:nomatch]
          Puppet.debug "not_augeas(handle_search_with_match) - Entering Match Block"
          if line_content =~ /#{r[:match]}/
            Puppet.debug "not_augeas(handle_search_with_match) - Match Found => #{line_content}"
            line_content.gsub!(/#{r[:search]}/, "#{r[:replace]}")
            new_file_contents << line_content
          else
            new_file_contents << line_content
          end
        elsif r[:nomatch] and not r[:match]
          Puppet.debug "not_augeas(handle_search_with_match) - Entering Nomatch Block"
          if line_content !~ /#{r[:nomatch]}/
            Puppet.debug "not_augeas(handle_search_with_match) - NoMatch Found => #{line_content}"
            line_content.gsub!(/#{r[:search]}/, "#{r[:replace]}")
            new_file_contents << line_content
          else
            new_file_contents << line_content
          end
        else
          new_file_contents << line_content
        end
      end
      file_opts[:content] = new_file_contents.join("\n")
      if file_opts[:content] !~ /\n$/
        file_opts[:content] += "\n"
      end

      Puppet.debug "not_augeas(handle_search_with_match) - :content => #{file_opts[:content].inspect}"

      Puppet.debug "not_augeas(handle_search_with_match) - file_opts => #{file_opts.inspect}"
    end

    return file_opts
  end

end
