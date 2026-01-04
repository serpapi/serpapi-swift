require 'rake'

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
  sh 'swift test'
end

desc 'run tests with coverage'
task :coverage do
  # Use main Xcode installation to find XCTest
  ENV['DEVELOPER_DIR'] ||= '/Applications/Xcode.app/Contents/Developer'
  
  sh 'swift test --enable-code-coverage'
  # Find the coverage report path
  bin_path = `swift build --show-bin-path`.strip
  package_name = "SerpApi" 
  
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

desc 'run demo example'
task :demo do
  sh 'swift run Demo'
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

