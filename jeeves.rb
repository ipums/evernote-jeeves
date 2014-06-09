
# A simple Evernote API script that finds all lines containing a search string
# in notes updated in the past N days

require 'digest/md5'
require 'evernote-thrift'
require 'pp'
require 'yaml'
require 'Sanitize'
require 'optparse'
require 'ostruct'

# command line options parsing
options = OpenStruct.new
OptionParser.new do |opts|
  opts.banner = "Usage: jeeves.rb [options]"

  #defaults
  options.verbose = FALSE
  options.search = 'TODO'
  options.days = 7

  opts.on("-v", "--verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end

  opts.on("-s", "--search", String, "Search string to look for in notes.") do |s|
    options[:search] = s
  end

  opts.on("-d", "--days", Integer, "Number of days in the past to search.") do |d|
    options[:days] = d
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

pp options

# get the authToken from config
config = YAML.load_file("config/config.yml")
authToken = config["config"]["authToken"]

# Since this app only accesses your own Evernote account, we can use a developer token
# that allows you to access your own Evernote account. To get a developer token, visit
# https://sandbox.evernote.com/api/DeveloperToken.action

if authToken == "your developer token"
  puts "Please fill in your developer token"
  puts "To get a developer token, visit https://sandbox.evernote.com/api/DeveloperToken.action"
  exit(1)
end

# Initial development is performed on our sandbox server. To use the production
# service, change "sandbox.evernote.com" to "www.evernote.com" and replace your
# developer token above with a token from
# https://www.evernote.com/api/DeveloperToken.action
#evernoteHost = "sandbox.evernote.com"
evernoteHost = "www.evernote.com"
userStoreUrl = "https://#{evernoteHost}/edam/user"

userStoreTransport = Thrift::HTTPClientTransport.new(userStoreUrl)
userStoreProtocol = Thrift::BinaryProtocol.new(userStoreTransport)
userStore = Evernote::EDAM::UserStore::UserStore::Client.new(userStoreProtocol)

versionOK = userStore.checkVersion("Evernote EDAM (Ruby)",
                                   Evernote::EDAM::UserStore::EDAM_VERSION_MAJOR,
                                   Evernote::EDAM::UserStore::EDAM_VERSION_MINOR)
raise RuntimeError, "API version out of date" unless versionOK

# Get the URL used to interact with the contents of the user's account
# When your application authenticates using OAuth, the NoteStore URL will
# be returned along with the auth token in the final OAuth request.
# In that case, you don't need to make this call.
noteStoreUrl = userStore.getNoteStoreUrl(authToken)

noteStoreTransport = Thrift::HTTPClientTransport.new(noteStoreUrl)
noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)

# search notes
noteFilter = Evernote::EDAM::NoteStore::NoteFilter.new
noteFilter.words = "updated:day-#{options.days} TODO"
spec = Evernote::EDAM::NoteStore::NotesMetadataResultSpec.new
spec.includeTitle = true
spec.includeNotebookGuid = true
noteList = noteStore.findNotesMetadata(authToken,noteFilter,0,100, spec)
puts "There are #{noteList.totalNotes} matching notes."
puts

noteList.notes.each do |note|
  puts "#{note.title} (#{noteStore.getNotebook(authToken, note.notebookGuid).name})"
  doc = noteStore.getNote(authToken, note.guid, true, false, false, false).content
  doc.lines.each do |line|
    if line[/TODO/]
      puts "  -" + Sanitize.clean(line).strip
    end
  end
  puts
end
