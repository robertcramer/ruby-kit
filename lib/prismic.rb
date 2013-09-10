require 'net/http'
require 'uri'

module Prismic

  # These exception can contains an error cause and is able to show them
  class Error < Exception
    attr_reader :cause
    def initialize(msg=nil, cause=nil)
      msg ? super(msg) : msg
      @cause = cause
    end
    def full_trace(e=self)
      first, *backtrace = e.backtrace
      msg = e == self ? "" : "Caused by "
      msg += "#{first}: #{e.message} (#{e.class})"
      stack = backtrace.map{|s| "\tfrom #{s}" }.join("\n")
      cause = e.respond_to?(:cause) ? e.cause : nil
      cause_stack = cause ? full_trace(cause) : nil
      [msg, stack, cause_stack].compact.join("\n")
    end
  end

  def self.api(*args)
    API.start(*args)
  end

  class ApiData
    attr_accessor :refs, :bookmarks, :types, :tags, :forms
  end

  class SearchForm
    attr_accessor :api, :form, :data

    def initialize(api, form, data=form.default_data)
      @api = api
      @form = form
      @data = data
    end

    def name
      form.name
    end

    def form_method
      form.form_method
    end

    def rel
      form.rel
    end

    def enctype
      form.enctype
    end

    def action
      form.action
    end

    def fields
      form.fields
    end

    def submit(ref)
      if form_method == "GET" && enctype == "application/x-www-form-urlencoded"
        data['ref'] = ref
        data.delete_if { |k, v| !v }

        uri = URI(action)
        uri.query = URI.encode_www_form(data)

        request = Net::HTTP::Get.new(uri.request_uri)
        request.add_field('Accept', 'application/json')

        response = Net::HTTP.new(uri.host, uri.port).start do |http|
          http.request(request)
        end

        raise RefNotFoundException, "Ref #{ref} not found" if response.code == "404"

        JSON.parse(response.body).map do |doc|
          Document.new(doc['id'], doc['type'], doc['href'], doc['tags'],
                       doc['slugs'], doc['data'].values.first)
        end
      else
        raise UnsupportedFormKind, "Unsupported kind of form: #{form_method} / #{enctype}"
      end
    end

    def query(query)
      strip_brakets = Proc.new {|str| str.strip[1, str.strip.length - 2]}

      previous_query = (not form.fields['q'].nil?) ? form.fields['q'].default.to_s : ''
      data['q'] = "[#{strip_brakets.call(previous_query)}#{strip_brakets.call(query)}]"
      self
    end

    class UnsupportedFormKind < Error ; end
    class RefNotFoundException < Error ; end
  end

  class Field
    attr_accessor :field_type, :default

    def initialize(field_type, default)
      @field_type = field_type
      @default = default
    end

  end

  class Document
    attr_accessor :id, :type, :href, :tags, :slugs, :fragments

    def initialize(id, type, href, tags, slugs, fragments)
      @id = id
      @type = type
      @href = href
      @tags = tags
      @slugs = slugs
      @fragments = fragments
    end

    def slug
      slugs.empty? ? '-' : slugs.first
    end
  end

  class Ref
    attr_accessor :ref, :label, :is_master, :scheduledAt

    def initialize(ref, label, is_master = false)
      @ref = ref
      @label = label.downcase
      @is_master = is_master
    end

    alias :master? :is_master
  end

end

require 'prismic/api'
require 'prismic/form'
require 'prismic/fragments'
