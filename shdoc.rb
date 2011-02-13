#!/usr/bin/env ruby
# -*- ruby -*-

require 'fileutils'

class ShDoc

  @verbose = false

  def main(argv)
    opts = argv.select {|x| x =~ /^-/}
    args = argv.reject {|x| x =~ /^-/}
    if opts.index '-h'
      print_help
      return
    end
    if opts.index '-v'
      @verbose = true
    end
    if args.empty?
      print_help
      return
    end
    if opts.index '-t'
      outdir = 'man/man1'
    else
      outdir = File.join ENV['HOME'],'man','man1'
    end
    FileUtils.mkdir_p outdir if not File.exist? outdir
    args.each do |f|
      generate outdir,f
    end
  end

  def print_code_comments(f)
    IO.foreach f do |line|
      code,cmts = get_code_comments line
      puts code
      puts cmts
      puts
    end
  end

  private

  def generate(outdir,f)

    # State while we iterate over the lines of the file
    in_function = false
    in_param = false
    in_return = false
    in_example = false
    name = nil
    num_curly_braces = 0
    last_comments = ''

    # Passed to generate
    state = {
      :description => nil,
      :params => nil,
      :return => nil,
      :example => nil,
      :in_param => nil,
      :in_return => nil,
      :in_exception => nil,
    }

    # Resets arguments passed to generate
    def reset(state)
      note 'Reset'
      state[:description] = ''
      state[:params] = []
      state[:return] = ''
      state[:example] = ''
      state[:in_param] = false
      state[:in_return] = false
      state[:in_example] = false
    end

    reset state

    IO.foreach f do |line|
      code,cmts = get_code_comments line
      if not in_function
        case cmts
        when /@param\s*([\S]+)\s+(.*)/
          name,descr =  $1,($2 || '')
          state[:params] << [name,descr]
          state[:in_param] = true
          state[:in_return] = false
          state[:in_example] = false
        when /@return\s*(.*)/
          state[:return] = $1
          state[:in_param] = false
          state[:in_return] = true
          state[:in_example] = false
        when /@example\s*(.*)/
          state[:example] = $1
          state[:in_param] = false
          state[:in_return] = false
          state[:in_example] = true
        else
          if state[:in_param]
            params = state[:params]
            params[params.length-1][1] += ' ' + cmts
          elsif state[:in_return]
            state[:return] += ' ' + cmts
          else
            if state[:description] != '' and last_comments == ''
              reset state
            end
            state[:description] += ' ' + cmts
          end
        end
      end

      if code
        if code =~ /^function\s+([^\(\{]+)\s*\(?\{?/
          name = $1
          in_function = true
          outfile = File.join outdir,name + '.1'
          generate_docs outfile,name,state[:description],state[:params],
          state[:return],state[:example]
          reset state
        end
        if in_function
          num_curly_braces += code.count '{'
          num_curly_braces -= code.count '}'
        end
        if in_function
          if num_curly_braces == 0
            in_function = false
            description = ''
          end
        end
      end
      
      last_comments = line.index('#') ? ' ' : cmts

    end
  end

  def massage(s)
    s = s.gsub /\s+/,' '
    s = s.strip
    s
  end

  def generate_docs(outfile,name,description,params,return_stmt,example)
    description = massage description
    description = name if not description or description == ''
    params = params.map {|ps| ps.map {|p| massage p }}
    return_stmt = massage return_stmt
    example = massage example
    note 'Generate docs'
    note ' outfile=' + outfile
    note ' name=' + name
    note ' description=' + description.to_s
    note ' params=' + params.to_s
    note ' return=' + return_stmt.to_s
    note ' example=' + example.to_s
    File.open outfile,'w' do |out|
      out.puts '.TH ' + name.upcase
      out.puts '.SH NAME'
      out.puts name
      out.puts '.SH SYNOPSIS'
      synopsis = name
      if not params.empty?
        synopsis += ' ' + params.map {|p| p[0]}.join(' ')
      end
      out.puts synopsis
      if description and description != ''
        out.puts '.SH DESCRIPTION'
        out.puts description
      end
      if not params.empty?
        out.puts '.SH OPTIONS'
        params.each do |p|
          key,val = p
          out.puts '.TP'
          out.puts '.B ' + key
          out.puts val
        end
      end
      if example and example != ''
        out.puts '.SH EXAMPLE'
        out.puts example
      end
      out.puts '.SH AUTHOR'
      out.puts ENV['USER']
    end
  end

  def get_code_comments(line)
    parts = line.split /\#/
    if parts.length == 2
      code,cmts = parts
    elsif line =~ /\#/
      code,cmts = ['',parts[0]]
    else
      code,cmts = [parts[0],'']
    end
    return code,cmts.strip
  end

  def note(s)
    STDERR.puts s if @verbose
  end

  def print_help
    STDERR.puts 'Usage ' + File.basename($0) + ' [options] file+'
    STDERR.puts 'where options include'
    STDERR.puts ' -h      print this message'
    STDERR.puts ' -v      verbose messages'
    STDERR.puts 'and inputs are files'
  end
  
end

ShDoc.new.main ARGV
