##
# This module requires Metasploit: http://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/core'

class Metasploit3 < Msf::Auxiliary
  include Msf::Exploit::Remote::Tcp
  include Msf::Auxiliary::Scanner
  include Msf::Auxiliary::Report

  def initialize
    super(
      'Name'        => 'Rsync Unauthenticated List Command',
      'Description' => 'List all (listable) modules from a rsync daemon',
      'Author'      => 'ikkini',
      'References'  =>
        [
          ['URL', 'http://rsync.samba.org/ftp/rsync/rsync.html']
        ],
      'License'     => MSF_LICENSE
    )
    register_options(
      [
        Opt::RPORT(873)
      ], self.class)
  end

  def run_host(ip)
    connect
    version = sock.get_once

    return if version.blank?
    version.strip!

    report_service(host: ip, port: rport, proto: 'tcp', name: 'rsync')
    report_note(
      host: ip,
      proto: 'tcp',
      port: rport,
      type: 'rsync_version',
      data: version
    )

    # making sure we match the version of the server
    sock.puts("#{version}\n")
    # the listing command
    sock.puts("#list\n")
    listing = sock.get(20)
    disconnect

    if listing.blank?
      print_status("#{ip}:#{port} - rsync #{version}: no modules found")
    else
      listing.gsub!('@RSYNCD: EXIT', '') # not interested in EXIT message
      listing.strip!
      # build a table to store the module listing in
      listing_table = Msf::Ui::Console::Table.new(
        Msf::Ui::Console::Table::Style::Default,
        'Header' => "rsync modules",
        'Prefix' => "\n",
        'Postfix' => "\n",
        'Indent' => 1,
        'Columns' =>
          [
            "Name",
            "Comment"
          ])

      # the module listing is the module name and comment separated by a tab, each module
      # on its own line, lines separated with a newline
      listing.split(/\n/).map do |share_line|
        name, comment = share_line.split(/\t/).map(&:strip)
        listing_table << [ name, comment ]
      end

      print_good("#{ip}:#{rport} - rsync #{version}: #{listing_table.rows.size} modules found")
      vprint_line(listing_table.to_s)

      report_note(
        host: ip,
        proto: 'tcp',
        port: rport,
        type: 'rsync_listing',
        data: listing_table
      )
    end
  end
end
