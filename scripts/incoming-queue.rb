#! /usr/bin/ruby

require 'net/smtp'

DEFAULT_DISTRIBUTION = "mustang"
DEFAULT_MAIL_RECIPIENTS = [ "rbscott@untangle.com", "seb@untangle.com" ]

REP = "/var/www/untangle"
INCOMING = "#{REP}/incoming"
PROCESSED = "#{REP}/processed"

def email(recipients, subject, body)
  recipientsString = recipients.join(',')
  recipients.each { |r|
    r.gsub!(/.*?<(.*)>/, '\1')
  }
  myMessage = <<EOM
From: Incoming Queue Daemon <seb@untangle.com>
To: #{recipientsString}
Subject: #{subject}

#{body}
EOM

  Net::SMTP.start('localhost', 25, 'localhost.localdomain') { |smtp|
    smtp.send_message(myMessage,"seb@untangle.com",*recipients)
  }
end

class DebianUpload

  @@doEmailSuccess = true
  @@doEmailFailure = true

  attr_reader :files, :distribution, :uploader, :version

  def initialize(file, move = true)
    @file = file
    @move = move
    @files = [ @file ]
  end

  def to_s
    s = "#{@file}\n"
    s += "  distribution = #{@distribution}\n"
    s += "  maintainer = #{@maintainer}\n"
    s += "  uploader = #{@uploader}\n"
    s += "  version = #{@version}\n"
    s += "  files =\n"
    @files.each { |file| 
      s += "    #{file}\n"
    }
    return s
  end

  def addToRepository
    begin
      if @uploader =~ /root/
        output = "#{@file} was built by root, not processing"
        puts output
        email(@emailRecipientsFailure,
              "Upload of #{File.basename(@name)} failed",
              output) if @@doEmailFailure
        return
      end

      output = `#{@command} 2>&1`
      if $? != 0
        output = "Something went wrong when adding #{@file}, leaving it in incoming/\n\n" + output
        puts output
        email(@emailRecipientsFailure + [@uploader, @maintainer],
              "Upload of #{@name} failed",
              output) if @@doEmailFailure
        return
      end
      
      if @move
        @files.each { |file|
          File.rename(file, "#{PROCESSED}/#{File.basename(file)}")
        }
      end

      puts output
      email(@emailRecipientsSuccess, "Upload of #{@file} succeeded",
            @files.inject("") { |result, e|
              result += e.gsub(/#{INCOMING}\//, "") + "\n"
            }) if @@doEmailSuccess
    rescue Exception => e
      puts e.message + "\n" + e.backtrace.join("\n")
      email(@emailRecipientsFailure,
            "Upload of #{@name} failed",
            e.message + "\n" + e.backtrace.join("\n")) if @@doEmailFailure
    end
  end
end

class PackageUpload < DebianUpload
  def initialize(file, move)
    super(file, move)
    @name = file.sub(/_.*/, "")
    @distribution = DEFAULT_DISTRIBUTION
    @command = "reprepro -V -b #{REP} --component upstream includedeb #{@distribution} #{@file}"
    @emailRecipientsSuccess = DEFAULT_MAIL_RECIPIENTS
    @emailRecipientsFailure = DEFAULT_MAIL_RECIPIENTS
  end
end

class ChangeFileUpload < DebianUpload
  def initialize(file, move)
    super(file, move)
    filesSection = false
    File.open(file).each { |line|
      line.strip!
      # FIXME: use a hash of /regex/ => :attribute
      case line
      when /^Source: / then
        @name = line.sub(/^Source: /, "")
      when /^Distribution: / then
        @distribution = line.sub(/^Distribution: /, "")
      when /^Maintainer: / then
        @maintainer = line.sub(/^Maintainer: /, "")
      when /^Changed-By: / then
        @uploader = line.sub(/^Changed-By: /, "")
      when /^Version: / then
        @version = line.sub(/^Version: /, "")
      when/^Files:/ then
        filesSection = true
        next
      when /^-----BEGIN PGP SIGNATURE-----/
        break # stop processing
      end
      
      if filesSection
        @files << line.sub(/.* /,"#{INCOMING}/")
      end
    }
    @command = "reprepro -Vb #{REP} include #{@distribution} #{@file}"
    @emailRecipientsSuccess = [ @uploader, @maintainer ].uniq
    @emailRecipientsFailure = @emailRecipientsSuccess + DEFAULT_MAIL_RECIPIENTS
  end
end

if ARGV.length == 1
  INCOMING = ARGV[0]
  move = false
else
  move = true
end

if File.directory?(INCOMING)
  Dir["#{INCOMING}/*.changes"].each { |file|
    cfu = ChangeFileUpload.new(file, move)
    cfu.addToRepository
  }

  Dir["#{INCOMING}/*.deb"].each { |file|
    pu = PackageUpload.new(file, move)
    pu.addToRepository
  }
else
  if INCOMING =~ /\.changes$/
    cfu = ChangeFileUpload.new(INCOMING, move)
    cfu.addToRepository
  else
    pu = PackageUpload.new(INCOMING, move)
    pu.addToRepository
  end
end
