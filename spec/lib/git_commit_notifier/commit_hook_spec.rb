# -*- coding: utf-8; mode: ruby; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- vim:fenc=utf-8:filetype=ruby:et:sw=2:ts=2:sts=2

require File.expand_path('../../../spec_helper', __FILE__)
require 'git_commit_notifier'

describe GitCommitNotifier::CommitHook do

  it "should ignore merge" do
    # 4 commits, one email for each of them, without merge
    run_with_config('spec/fixtures/git-notifier-ignore-merge.yml', 4)
  end

  it "should hook with merge" do
    # 5 commits, one email for each of them, with merge mail
    run_with_config('spec/fixtures/git-notifier-with-merge.yml', 5)
  end

  it "should hook group email by push" do
    # 1 commit for the push, all commits in the one message
    run_with_config('spec/fixtures/git-notifier-group-email-by-push.yml', 1)
  end

  it "should ignore commits to non specified branches if branch limits supplied" do
    # 4 commits, one email for each of them, without merge
    run_and_reject('spec/fixtures/git-notifier-with-branch-restrictions.yml',0,'refs/heads/branchx')
  end

  it "should email for commits to branch in include_branch" do
    # 4 commits, one email for each of them, without merge
    run_with_config('spec/fixtures/git-notifier-with-branch-restrictions.yml',4,'refs/heads/branch2')
  end


  it "should email for commits to master if master set as include_branch" do
    # 4 commits, one email for each of them, without merge
    run_with_config('spec/fixtures/git-notifier-with-branch-restrictions.yml',4)
  end


  def run_with_config(config, times, branch = 'refs/heads/master')
    expect_repository_access

    emailer = mock!.send.times(times).subject
    double(GitCommitNotifier::Emailer).new(anything, anything) { emailer }.times(times)
    double(GitCommitNotifier::CommitHook).info(/Sending mail/)

    any_instance_of(GitCommitNotifier::DiffToHtml, :check_handled_commits => lambda { |commits| commits })
    GitCommitNotifier::CommitHook.run config, REVISIONS.first, REVISIONS.last, branch
  end


  def run_and_reject(config,times,branch)
    double(GitCommitNotifier::Git).mailing_list_address { 'recipient@test.com' }
    double(GitCommitNotifier::Git).repo_name { 'testproject' }

    emailer = mock!.send.times(times).subject
    double(GitCommitNotifier::Emailer).new(anything, anything).times(times)

    double(GitCommitNotifier::CommitHook).info(/Supressing mail for branch/)

    GitCommitNotifier::CommitHook.run config, REVISIONS.first, REVISIONS.last, branch
  end


  def test_commit_from
    # 1 commit with a from: adress
    expect_repository_access
    emailer = mock!.send.subject
    double(GitCommitNotifier::Emailer).new(anything, hash_including(:from_address => "max@example.com")) { emailer }

    GitCommitNotifier::CommitHook.run 'spec/fixtures/git-notifier-group-email-by-push.yml', REVISIONS.first, REVISIONS.last, 'refs/heads/master'
   end

  def expect_repository_access
    double(GitCommitNotifier::Git).rev_type(REVISIONS.first) { "commit" }
    double(GitCommitNotifier::Git).rev_type(REVISIONS.last) { "commit" }
    double(GitCommitNotifier::Git).new_commits(anything, anything, anything, anything) { REVISIONS }
    double(GitCommitNotifier::Git).mailing_list_address { 'recipient@test.com' }
    double(GitCommitNotifier::Git).repo_name { 'testproject' }
    double(GitCommitNotifier::Git).changed_files('7e4f6b4', '4f13525') { [] }
    REVISIONS.each do |rev|
      double(GitCommitNotifier::Git).show(rev, :ignore_whitespace => 'all') { IO.read(FIXTURES_PATH + "git_show_#{rev}") }
      dont_allow(GitCommitNotifier::Git).describe(rev) { IO.read(FIXTURES_PATH + "git_describe_#{rev}") }
    end
  end

  describe :logger do
    it "should be instance of logger" do
      double(GitCommitNotifier::CommitHook).config { {} }
      expect(GitCommitNotifier::CommitHook.logger).to be_kind_of(GitCommitNotifier::Logger)
    end
  end

  describe :show_error do
    it "should write error to stderr" do
      double($stderr).puts("\n").times(2)
      double($stderr).puts(/GIT\sNOTIFIER\sPROBLEM/).times(2)
      double($stderr).puts('yes')
      GitCommitNotifier::CommitHook.show_error('yes')
    end
  end

  describe :info do
    it "should write to and flush stdout" do
      double($stdout).puts('msg')
      double($stdout).flush
      GitCommitNotifier::CommitHook.info('msg')
    end
  end

  describe :run do
    it "should report informational message when no recipients specified" do
      double(File).exists?(:noconfig) { false }
      double(GitCommitNotifier::CommitHook).info(/Unable to find/)
      double(GitCommitNotifier::Git).mailing_list_address { nil }
      double(GitCommitNotifier::CommitHook).info(/recipient/)
      GitCommitNotifier::CommitHook.run(:noconfig, :rev1, :rev2, 'master')
    end
  end

  describe :include_branches do
    it "should be nil if not specified in config" do
      double(GitCommitNotifier::CommitHook).config { Hash.new }
      expect(GitCommitNotifier::CommitHook.include_branches).to be_nil
    end
    it "should be single item array if one branch as string specified" do
      double(GitCommitNotifier::CommitHook).config { { 'include_branches' => 'staging' } }
      expect(GitCommitNotifier::CommitHook.include_branches).to eq(%w( staging ))
    end
    it "should be array if specified as array" do
      double(GitCommitNotifier::CommitHook).config { { 'include_branches' => %w(test staging gotcha)  } }
      expect(GitCommitNotifier::CommitHook.include_branches).to eq(%w(test staging gotcha))
    end
    it "should be array of items, splitted by comma if specified as comma-separated list string" do
      double(GitCommitNotifier::CommitHook).config { { 'include_branches' => 'test, me, yourself'  } }
      expect(GitCommitNotifier::CommitHook.include_branches).to eq(%w(test me yourself))
    end
  end

  describe :get_subject do
    it "should run lambda if specified in mapping" do
      double(GitCommitNotifier::Git).describe("commit_id") { "yo" }
      expect(GitCommitNotifier::CommitHook.get_subject(
        { :commit => "commit_id" },
        "${description}",
        { :description => lambda { |commit_info| GitCommitNotifier::Git.describe(commit_info[:commit]) } }
      )).to eq("yo")
    end
  end

end
