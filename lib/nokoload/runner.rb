require 'uri'
require 'net/http'
require 'nokogiri'
require 'nokoload/form_data'
require 'nokoload/multipart'

module Nokoload
  class Runner
    attr_accessor :url, :stop_on_first_exception, :trace, :read_timeout
    attr_reader :timer, :step_times, :request_times, :mutex, :wall_time


    def initialize
      @mutex=Mutex.new
      @read_timeout=500
      @step_times={}
      @request_times=[]
      @wall_time=0
      @timer=0.0
    end

    def sync(&block)
      @mutex.synchronize{instance_eval(&block)}
    end

    def running?
      @mutex.synchronize {
        return false if (@ts.nil? || @ts.empty?)
        @ts.map! {|t| t.join(0) ? nil : t }.compact!
        stop_clock if @ts.empty?
        return !@ts.empty?
      }
    end

    def after(seconds)
      @last_time+=seconds
      time=@last_time-Time.new
      sleep time if time > 0
    end

    # if run already in progress then wait for it to complete before starting
    def run(number=1)
      if running?
        wait_for_run
      end
      start_clock
      @last_time=Time.new
      ts=[]
      (0...number).each do |i|
        pipe = IO.popen('-','w+')
        if pipe
          ts << pipe
        else
          ts=nil
          begin
            yield i
          rescue
            puts "\0Exception\0#{$!.class.name} : #{$!}"
            puts $!.backtrace.join("\n")
          ensure
            exit!(0)
          end
        end
      end
      i=-1
      ts.map! do |p|
        Thread.new(i+=1,p) do |tn,pipe|
          begin
            # TODO puts "START: #{tn} - pid #{pipe.pid}"
            while line=pipe.gets
              if line[0..0] == "\0"
                args=line.split("\0")[1..-1]
                case args[0]
                when "__STEP_STAT__"
                  record_step_time(*line.split("\0")[2..-1])
                when "__RQST_STAT__"
                  record_request_time(*line.split("\0")[2..-1])
                when "Exception"
                  @exception=args[1]
                  puts "Thread: #{tn}: Exception '#{args[1].chop}'"
                end
              else
                puts "Thread: #{tn}: #{line}"
              end
            end
            exit(1) if @exception && stop_on_first_exception
            # TODO puts "END:  #{tn} - pid #{pipe.pid}"
          rescue
            puts $!
          end
        end
      end

      @ts=ts
    end

    def wait_for_run
      @ts.each do |t|
        t.join
      end
      @ts.clear
      stop_clock
    end

    def submit(button,fields={})
      begin
        raise "submit button '#{button}' not found" unless elm=css("input[type=submit][value='#{button}']").first
        raise "Can't find form for submit button '#{button}'" unless form=up(elm,'form')
        if form['enctype'] == 'multipart/form-data'
          method=:upload
        else
          method=form['method'] || :post
        end
        comm(method.to_sym, form.attribute('action').to_s, FormData.new({elm.attribute('name').to_s => elm.attribute('value').to_s},form).
             fill_values_by_labels(fields).add_form)
      rescue Exception => e
        puts "Error submitting: #{button.inspect}, #{fields.inspect}"
        raise e
      end
    end

    def up(elm,node_name)
      elm=elm.parent
      return elm if elm.nil? || elm.node_name.casecmp(node_name) == 0
      up(elm,node_name)
    end

    def xhr
      @xhr={'X-Requested-With' => 'XMLHttpRequest', 'Accept' => 'text/javascript, text/html, application/xml, text/xml, */*'}
    end

    def comm(cmd,path,params,headers={})
      puts "#{cmd} #{path} params=#{params}, headers=#{headers.inspect}" if trace
      @comm_start=Time.new
      @start_dur=@timer
      headers||={}
      headers['Cookie']=cookies unless headers.include?('Cookie')
      if @xhr
        headers.merge!(@xhr)
        @xhr=nil
      else
        @doc=nil
      end
      @response=Net::HTTP.start(url.host, url.port) do |http|
        http.read_timeout=read_timeout
        case cmd
        when :get
          if params
            params=(FormData === params ? params : FormData.new(params)).to_params
            time{http.get("#{path}?#{params}", {'Cookie' => cookies})}
          else
            time{http.get(path, headers)}
          end
        when :post
          req=Net::HTTP::Post.new(path, headers)
          req.content_type = 'application/x-www-form-urlencoded'
          req.body = (FormData === params ? params : FormData.new(params)).to_params if params
          time{http.request(req)}
        when :upload
          boundary = '----RubyMultipartClient#{Time.new.to_f}ZZZZZ'
          req=Net::HTTP::Post.new(path, headers)
          req.content_type = 'multipart/form-data; boundary=' + boundary
          parts = []
          streams = []
          params.form_files.each do |param_name, filepath|
            filename = File.basename(filepath)
            parts << StringPart.new( "--#{boundary}\r\n" \
                                     "Content-Disposition: form-data; name=\"#{param_name}\"; filename=\"#{filename}\"\r\n" \
                                     "Content-Type: text/plain\r\n\r\n")
            stream = File.open(filepath, "r")
            streams << stream
            parts << StreamPart.new(stream, File.size(filepath))
          end if params
          (FormData === params ? params : params=FormData.new(params)).each_param do |name, value|
            parts << StringPart.new("--#{boundary}\r\n" \
                                    "Content-Type: application/x-www-form-urlencoded\r\n" \
                                    "Content-Disposition: form-data; name=\"#{name}\"\r\n\r\n#{value}")
          end
          parts << StringPart.new( "\r\n--" + boundary + "--\r\n" )
          post_stream=MultipartStream.new( parts )
          req.content_length = post_stream.size
          req.body_stream = post_stream
          begin
            time{http.request(req)}
          ensure
            streams.each { |stream| stream.close() }
          end
        else
          raise "unsupported command: #{cmd}"
        end
      end
      @response=handle_response(cmd,path,@response)
    rescue
      puts "Comms Error: #{cmd}: #{url}#{path} params=#{params.inspect}, headers=#{headers.inspect}"
      raise
    end

    def handle_response(cmd,path,response, limit=10)
      puts "\0__RQST_STAT__\0#{cmd == :get ? :get : :post}\0#{path}\0#{@comm_start.to_i}\0#{((@timer-@start_dur)*1000).to_i}"
      case response
      when Net::HTTPSuccess     then response
      when Net::HTTPRedirection then redirect(response, limit)
      else
        response.error!
      end
    end

    def redirect(response,limit)
      raise ArgumentError, 'HTTP redirect too deep' if limit == 0
      # TODO puts "redirected => #{response['location']}"
      uri=URI.parse(response['location'])
      @comm_start=Time.new
      @start_dur=@timer
      handle_response(:get,uri.path,Net::HTTP.start(url.host, url.port) { |http| time{http.get(uri.path, {'Cookie' => cookies}) }},limit -1)
    end

    def step(name) # :yield: level
      old_name=@step_name
      old_timer=@timer
      @step_name=@step_name ? "#{old_name}/#{name}" : name
      @timer=0.0
      begin
        yield
      ensure
        print_step_time
        @step_name=old_name
        @timer+=old_timer
      end
    end

    def print_step_time
      if @step_name
        puts "\0__STEP_STAT__\0#@step_name\0#@timer"
      end
    end

    def time # :yield:
      t0=Time.now.to_f
      begin
        return yield
      ensure
        t1=Time.now.to_f
        @timer+=t1-t0
      end
    end

    def record_step_time(step_name,time)
      @mutex.synchronize do
        (@step_times[step_name]||=[]) << time.to_f
      end
    end

    def record_request_time(cmd,path,start_time,duration)
      @mutex.synchronize do
        @request_times << [cmd, path, start_time.to_i, duration.to_i]
      end
    end

    def cookies
      @response ? @response['Set-Cookie'] : ''
    end

    def css(*args,&block)
      rep_doc.css(*args,&block)
    end

    def content(content,css)
      css(css).find { |elm| elm.content.strip == content }
    end

    def rep_doc
      @doc||=Nokogiri::HTML(@response.body)
    end

    def response_body
      @response.body
    end

    def start_clock
      @clock_start=Time.new
    end

    def stop_clock
      if @clock_start
        @wall_time+=Time.new-@clock_start
        @clock_start=nil
      end
    end
  end
end
