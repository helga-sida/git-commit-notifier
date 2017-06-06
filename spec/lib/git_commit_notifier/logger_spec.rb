# -*- coding: utf-8; mode: ruby; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- vim:fenc=utf-8:filetype=ruby:et:sw=2:ts=2:sts=2

require File.expand_path('../../../spec_helper', __FILE__)
require 'git_commit_notifier'

describe GitCommitNotifier::Logger do
  describe :debug? do
    it "should be false unless debug section exists" do
      logger = GitCommitNotifier::Logger.new({})
      expect(logger).not_to be_debug
    end

    it "should be false unless debug/enabled" do
      logger = GitCommitNotifier::Logger.new("debug" => { "enabled" => false })
      expect(logger).not_to be_debug
    end

    it "should be true if debug/enabled" do
      logger = GitCommitNotifier::Logger.new("debug" => { "enabled" => true })
      expect(logger).to be_debug
    end
  end

  describe :log_directory do
    it "should be nil unless debug?" do
      logger = GitCommitNotifier::Logger.new({})
      expect(logger).not_to be_debug
      expect(logger.log_directory).to be_nil
    end

    it "should be custom if debug and custom directory specified" do
      expected = Faker::Lorem.sentence
      logger = GitCommitNotifier::Logger.new("debug" => { "enabled" => true, "log_directory" => expected})
      expect(logger.log_directory).to eq(expected)
    end

    it "should be default log directory if debug and custom directory not specified" do
      logger = GitCommitNotifier::Logger.new("debug" => { "enabled" => true })
      expect(logger.log_directory).to eq(GitCommitNotifier::Logger::DEFAULT_LOG_DIRECTORY)
    end
  end

  describe :log_path do
    it "should be nil unless debug?" do
      logger = GitCommitNotifier::Logger.new({})
      double(logger).debug? { false }
      expect(logger.log_path).to be_nil
    end

    it "should be path in log_directory if debug?" do
      logger = GitCommitNotifier::Logger.new("debug" => { "enabled" => true })
      expect(File.dirname(logger.log_path)).to eq(logger.log_directory)
    end

    it "should points to LOG_NAME if debug?" do
      logger = GitCommitNotifier::Logger.new("debug" => { "enabled" => true })
      expect(File.basename(logger.log_path)).to eq(GitCommitNotifier::Logger::LOG_NAME)
    end
  end
end

