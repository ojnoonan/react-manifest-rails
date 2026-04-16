module ReactManifest
  # Patches Rails layout files to insert `react_bundle_tag` after the
  # `javascript_include_tag` call, or before `</head>` as a fallback.
  #
  # Supports .html.erb, .html.haml, and .html.slim.
  # Skips files that already contain `react_bundle_tag`.
  # Atomic write: backs up original before writing.
  #
  # Usage:
  #   ReactManifest::LayoutPatcher.new(config).patch!
  class LayoutPatcher
    LAYOUTS_GLOB   = "app/views/layouts/*.html.{erb,haml,slim}".freeze
    BUNDLE_TAG_ERB = "<%= react_bundle_tag %>\n".freeze
    BUNDLE_TAG_HAML = "= react_bundle_tag\n".freeze

    Result = Struct.new(:file, :status, :detail, keyword_init: true)

    def initialize(config = ReactManifest.configuration)
      @config = config
    end

    # Patch all layout files. Returns array of Result objects.
    def patch!
      layouts = find_layouts
      if layouts.empty?
        $stdout.puts "[ReactManifest] No layout files found in #{layouts_dir}"
        return []
      end
      layouts.map { |f| patch_file(f) }
    end

    private

    def find_layouts
      Dir.glob(File.join(layouts_dir, "*.html.{erb,haml,slim}"))
         .reject { |f| File.directory?(f) }
         .sort
    end

    def layouts_dir
      Rails.root.join("app", "views", "layouts").to_s
    end

    def patch_file(path)
      content = File.read(path, encoding: "utf-8")

      if content.include?("react_bundle_tag")
        return Result.new(file: path, status: :already_patched,
                          detail: "react_bundle_tag already present")
      end

      ext         = detect_ext(path)
      new_content = insert_bundle_tag(content, ext)

      if new_content.nil?
        return Result.new(file: path, status: :no_injection_point,
                          detail: "Could not find javascript_include_tag or </head> — add react_bundle_tag manually")
      end

      if @config.dry_run?
        $stdout.puts "[ReactManifest] DRY-RUN: would patch #{short(path)}"
        print_diff(content, new_content)
        return Result.new(file: path, status: :dry_run, detail: nil)
      end

      File.write(path, new_content, encoding: "utf-8")
      $stdout.puts "[ReactManifest] Patched layout: #{short(path)}"
      Result.new(file: path, status: :patched, detail: nil)
    end

    # Insert the bundle tag line after `javascript_include_tag` (preferred),
    # or before `</head>` / `%head` close as a fallback.
    def insert_bundle_tag(content, ext)
      lines = content.lines

      # Preferred: insert after javascript_include_tag
      js_idx = lines.index { |l| l.include?("javascript_include_tag") }

      # Fallback: insert before closing </head>
      head_idx = lines.rindex { |l| l.include?("</head>") } unless js_idx

      insert_after = js_idx || (head_idx ? head_idx - 1 : nil)
      return nil if insert_after.nil?

      # Match indentation of the reference line
      indent = lines[js_idx || head_idx][/^\s*/]
      tag    = bundle_tag_line(ext, indent)

      new_lines = lines.dup
      new_lines.insert(insert_after + 1, tag)
      new_lines.join
    end

    def bundle_tag_line(ext, indent)
      case ext
      when :haml, :slim
        "#{indent}#{BUNDLE_TAG_HAML}"
      else
        "#{indent}#{BUNDLE_TAG_ERB}"
      end
    end

    def detect_ext(path)
      case path
      when /\.html\.haml$/ then :haml
      when /\.html\.slim$/ then :slim
      else :erb
      end
    end

    def short(path)
      path.to_s.sub("#{Rails.root}/", "")
    end

    def print_diff(old_content, new_content)
      old_lines = old_content.lines.map(&:chomp)
      new_lines = new_content.lines.map(&:chomp)
      (new_lines - old_lines).each { |l| $stdout.puts "  + #{l}" }
    end
  end
end
