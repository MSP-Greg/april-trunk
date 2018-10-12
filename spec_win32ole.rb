require 'win32ole'

module SpecWin32Ole
class << self

  def run
    begin
      ie = WIN32OLE.new 'InternetExplorer.Application'
      puts "\nie created", ""
    rescue => e
      puts e.class
      puts e.message
    end

    if ie
    
      begin
        ie.ole_func_methods(1)
      rescue => e
        puts "ie.ole_func_methods - #{e.class} - #{e.message}"
      end
      puts

      t = ie.ole_func_methods.all? { |m| m.kind_of? WIN32OLE_METHOD }
      puts "ie.ole_func_methods.all? { |m| m.kind_of? WIN32OLE_METHOD }"
      puts "   should be true - #{t}"
      puts

      t = ie.ole_func_methods.map { |m| m.name }.include?('AddRef')
      puts "ie.ole_func_methods.map { |m| m.name }.include?('AddRef')"
      puts "   should be true - #{t}"
      puts
      ie.Quit
      ie = nil    
    end
  end

end
end
SpecWin32Ole.run
