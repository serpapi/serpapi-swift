require 'rake'
require 'json'

desc "run out of box testing using the local build"
task oobt: %i[check build demo]

desc "execute all the steps"
task default: %i[check dependency version build test oobt]

desc 'install project dependencies'
task :dependency do
  sh 'swift package update'
end

desc 'build serpapi library'
task :build do
  sh 'swift build'
end

desc 'run tests'
task :test do
  ENV['DEVELOPER_DIR'] ||= '/Applications/Xcode.app/Contents/Developer'
  sh 'swift test'
end

namespace :examples do
  desc 'run demo tests'
  task :demo do
    ENV['DEVELOPER_DIR'] ||= '/Applications/Xcode.app/Contents/Developer'
    puts "Running tests for Examples/Demo..."
    sh 'swift test --package-path Examples/Demo'
  end

  desc 'run events demo tests'
  task :events_demo do
    ENV['DEVELOPER_DIR'] ||= '/Applications/Xcode.app/Contents/Developer'
    puts "Running tests for Examples/EventsDemo..."
    sh 'swift test --package-path Examples/EventsDemo'
  end
end

desc 'run tests with coverage'
task :coverage do
  # Use main Xcode installation to find XCTest
  ENV['DEVELOPER_DIR'] ||= '/Applications/Xcode.app/Contents/Developer'
  
  sh 'swift test --enable-code-coverage'
  # Find the coverage report path
  bin_path = `swift build --show-bin-path`.strip
  
  # The coverage data is usually in .build/debug/codecov/default.profdata
  # We need to process it with llvm-cov
  
  # Try to find llvm-cov
  llvm_cov = `xcrun -f llvm-cov 2>/dev/null`.strip
  if llvm_cov.empty?
    puts "llvm-cov not found. Please ensure Xcode command line tools are installed."
  else
    # Generate report
    # Note: We need to target the test bundle executable
    xctest_path = Dir.glob("#{bin_path}/*.xctest/Contents/MacOS/*").first || Dir.glob("#{bin_path}/*.xctest/*").first
    
    if xctest_path
      puts "Generating coverage report..."
      sh "#{llvm_cov} report #{xctest_path} -instr-profile=.build/debug/codecov/default.profdata -ignore-filename-regex='.build|Tests'"
    else
      puts "Could not find xctest binary for coverage report"
    end
  end
end

desc 'validate all the examples (comprehensive set of tests)'
task :regression do
  puts 'Regression tests not implemented yet'
end

desc 'run benchmark tests'
task :benchmark do
  puts 'Benchmark tests not implemented yet'
end

desc 'run linting'
task :lint do
  if which('swiftlint')
    sh 'swiftlint'
  else
    puts 'swiftlint not found, skipping lint'
  end
end

desc 'format swift code'
task :format do
  if which('swiftformat')
    sh 'swiftformat .'
  else
    puts 'swiftformat not found, skipping format'
  end
end

desc 'generate documentation'
task :doc do
  sh 'swift package generate-documentation'
end

namespace :demo do
  desc 'run demo in iOS simulator'
  task :ios do
    # Ensure we use the full Xcode path for simulator tools
    developer_dir = '/Applications/Xcode.app/Contents/Developer'
    ENV['DEVELOPER_DIR'] = developer_dir if File.exist?(developer_dir)
    
    # 1. Find a simulator
    puts "Searching for available iOS simulator..."
    devices = `xcrun simctl list devices available -j`
    begin
      data = JSON.parse(devices)
      # Find first booted or first available iPhone
      all_devices = data['devices'].values.flatten
      device = all_devices.find { |d| d['state'] == 'Booted' && d['name'].include?('iPhone') }
      device ||= all_devices.find { |d| d['name'].include?('iPhone') }
      
      if device
        device_id = device['udid']
        puts "Using device: #{device['name']} (#{device_id})"
        
        # 2. Boot if needed
        if device['state'] != 'Booted'
          puts "Booting simulator..."
          sh "xcrun simctl boot #{device_id}"
          sh "open -a Simulator"
        end
        
        # 3. Build for simulator
        puts "Building EventsDemo for iOS Simulator..."
        derived_data = ".build/derived_data"
        sh "xcodebuild build -scheme EventsDemo -destination 'platform=iOS Simulator,id=#{device_id}' -derivedDataPath #{derived_data} -project Examples/EventsDemo/.build/EventsDemo.xcodeproj" rescue nil
        # xcodebuild might not work directly on a folder without generating a project first or if it's a SPM package.
        # For SPM packages in subfolders, we should use -project if we generated one, or just build from the folder.
        sh "cd Examples/EventsDemo && xcodebuild build -scheme EventsDemo -destination 'platform=iOS Simulator,id=#{device_id}' -derivedDataPath ../../.build/derived_data"
        
        # 4. Find the .app and Bundle ID
        app_path = Dir.glob("#{derived_data}/Build/Products/*-iphonesimulator/EventsDemo.app").first
        if app_path
          bundle_id = `defaults read "#{File.expand_path(app_path)}/Info.plist" CFBundleIdentifier`.strip
          puts "Installing #{bundle_id}..."
          sh "xcrun simctl install #{device_id} '#{app_path}'"
          puts "Launching..."
          sh "xcrun simctl launch #{device_id} #{bundle_id}"
        else
          puts "Error: Could not find built .app in #{derived_data}"
        end
      else
        puts "Error: No iPhone simulator found. Please create one in Xcode or use 'open -a Simulator' first."
      end
    rescue => e
      puts "Error: #{e.message}"
      puts "Falling back to 'swift run EventsDemo' (macOS version)"
      sh "swift run EventsDemo"
    end
  end

  desc 'run GUI EventsDemo in macOS'
  task :macos do
    sh 'swift run --package-path Examples/EventsDemo'
  end
end

desc 'print current version'
task :version do
  sh "grep 'static let version' Sources/SerpApi/Version.swift"
end

desc 'create a git tag'
task :tag do
  version = `grep 'static let version' Sources/SerpApi/Version.swift | cut -d '"' -f 2`.strip
  puts "create git tag #{version}"
  sh "git tag #{version}"
  puts "now publish the tag:\n$ git push origin #{version}"
end

task :check do
  if ENV['SERPAPI_KEY']
    puts 'check: found $SERPAPI_KEY'
  else
    puts 'check: SERPAPI_KEY must be defined'
    exit 1
  end
end

def which(cmd)
  exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
    exts.each do |ext|
      exe = File.join(path, "#{cmd}#{ext}")
      return exe if File.executable?(exe) && !File.directory?(exe)
    end
  end
  nil
end

