# A rush box is a single unix machine - a server, workstation, or VPS instance.
#
# Specify a box by hostname (default = 'localhost').  If the box is remote, the
# first action performed will attempt to open an ssh tunnel.  Use square
# brackets to access the filesystem, or processes to access the process list.
#
# Example:
#
#   local = Rush::Box.new('localhost')
#   local['/etc/hosts'].contents
#   local.processes
#
class Rush::Box
	attr_reader :host

	# Instantiate a box.  No action is taken to make a connection until you try
	# to perform an action.  If the box is remote, an ssh tunnel will be opened.
	# Specify a username with the host if the remote ssh user is different from
	# the local one (e.g. Rush::Box.new('user@host')).
	def initialize(host='localhost')
		@host = host
	end

	def to_s        # :nodoc:
		host
	end

	def inspect     # :nodoc:
		host
	end

	# Access / on the box.
	def filesystem
		Rush::Entry.factory('/', self)
	end

	# Look up an entry on the filesystem, e.g. box['/path/to/some/file'].
	# Returns a subclass of Rush::Entry - either Rush::Dir if you specifiy
	# trailing slash, or Rush::File otherwise.
	def [](key)
		filesystem[key]
	end

	# Get the list of processes currently running on the box.  Returns an array
	# of Rush::Process.
	def processes
		connection.processes.map do |ps|
			Rush::Process.new(ps, self)
		end
	end

	# Execute a command in the standard unix shell.  Options:
	#
	# :user => unix username to become via sudo
	# :env => hash of environment variables
	#
	# Example:
	#
	#   box.bash '/etc/init.d/mysql restart', :user => 'root'
	#   box.bash 'rake db:migrate', :user => 'www', :env => { :RAILS_ENV => 'production' }
	#
	def bash(command, options={})
		connection.bash(command_with_environment(command, options[:env]), options[:user])
	end

	def command_with_environment(command, env)   # :nodoc:
		return command unless env

		vars = env.map do |key, value|
			"export #{key}='#{value}'"
		end
		vars.push(command).join("\n")
	end

	# Returns true if the box is responding to commands.
	def alive?
		connection.alive?
	end

	# This is called automatically the first time an action is invoked, but you
	# may wish to call it manually ahead of time in order to have the tunnel
	# already set up and running.  You can also use this to pass a timeout option,
	# either :timeout => (seconds) or :timeout => :infinite.
	def establish_connection(options={})
		connection.ensure_tunnel(options)
	end

	def connection         # :nodoc:
		@connection ||= make_connection
	end

	def make_connection    # :nodoc:
		host == 'localhost' ? Rush::Connection::Local.new : Rush::Connection::Remote.new(host)
	end

	def ==(other)          # :nodoc:
		host == other.host
	end
end
