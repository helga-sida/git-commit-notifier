# -*- coding: utf-8; mode: ruby; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- vim:fenc=utf-8:filetype=ruby:et:sw=2:ts=2:sts=2

require File.expand_path('../../../spec_helper', __FILE__)
require 'git_commit_notifier'

describe GitCommitNotifier::Git do
  SAMPLE_REV = '51b986619d88f7ba98be7d271188785cbbb541a0'.freeze
  SAMPLE_REV_2 = '62b986619d88f7ba98be7d271188785cbbb541b1'.freeze

  describe :from_shell do
    it "should be backtick" do
      expect(GitCommitNotifier::Git.from_shell('pwd')).to eq(`pwd`)
    end
  end

  describe :show do
    it "should get data from shell: git show without whitespaces" do
      expected = 'some data from git show'
      double(GitCommitNotifier::Git).from_shell("git show #{SAMPLE_REV} --date=rfc2822 --pretty=fuller -M0.5 -w") { expected }
      expect(GitCommitNotifier::Git.show(SAMPLE_REV, :ignore_whitespace => 'all')).to eq(expected)
    end

    it "should get data from shell: git show with whitespaces" do
      expected = 'some data from git show'
      double(GitCommitNotifier::Git).from_shell("git show #{SAMPLE_REV} --date=rfc2822 --pretty=fuller -M0.5") { expected }
      expect(GitCommitNotifier::Git.show(SAMPLE_REV, :ignore_whitespace => 'none')).to eq(expected)
    end

    it "should strip given revision" do
      double(GitCommitNotifier::Git).from_shell("git show #{SAMPLE_REV} --date=rfc2822 --pretty=fuller -M0.5 -w")
      GitCommitNotifier::Git.show("#{SAMPLE_REV}\n", :ignore_whitespace => 'all')
    end
  end

  describe :describe do
    it "should strip given description" do
      expected = 'some descriptio'
      double(GitCommitNotifier::Git).from_shell("git describe --always #{SAMPLE_REV}") { "#{expected}\n" }
      expect(GitCommitNotifier::Git.describe(SAMPLE_REV)).to eq(expected)
    end
  end

  describe :branch_heads do
    before(:each) do
      double(GitCommitNotifier::Git).from_shell("git rev-parse --branches") { "some\npopular\ntext\n" }
    end

    it "should get branch heads from shell" do
      expect { GitCommitNotifier::Git.branch_heads }.not_to raise_error
    end

    it "should return array of lines" do
      expect(GitCommitNotifier::Git.branch_heads).to eq(%w[ some popular text ])
    end
  end


  describe :repo_name do
    # this spec written because I replaced `pwd` with Dir.pwd
    it "Dir.pwd should be same as `pwd`.chomp" do
      expect(Dir.pwd).to eq(`pwd`.chomp)
    end

    it "should return hooks.emailprefix if it's not empty" do
      expected = "name of repo"
      double(GitCommitNotifier::Git).from_shell("git config hooks.emailprefix") { expected }
      dont_allow(Dir).pwd
      expect(GitCommitNotifier::Git.repo_name).to eq(expected)
    end

    it "should return folder name if no emailprefix and directory not ended with .git" do
      double(GitCommitNotifier::Git).from_shell("git config hooks.emailprefix") { " " }
      double(GitCommitNotifier::Git).toplevel_dir { "/home/someuser/repositories/myrepo" }
      expect(GitCommitNotifier::Git.repo_name).to eq("myrepo")
    end

    it "should return folder name without extension if no emailprefix and directory ended with .git" do
      double(GitCommitNotifier::Git).from_shell("git config hooks.emailprefix") { " " }
      double(GitCommitNotifier::Git).toplevel_dir { "/home/someuser/repositories/myrepo.git" }
      expect(GitCommitNotifier::Git.repo_name).to eq("myrepo")
    end

    it "should return folder name if no emailprefix and toplevel dir and directory not ended with .git" do
      double(GitCommitNotifier::Git).from_shell("git config hooks.emailprefix") { " " }
      double(GitCommitNotifier::Git).toplevel_dir { "" }
      double(GitCommitNotifier::Git).git_dir { "/home/someuser/repositories/myrepo.git" }
      expect(GitCommitNotifier::Git.repo_name).to eq("myrepo")
    end

  end

  describe :repo_name_with_parent do
    # this spec written because I replaced `pwd` with Dir.pwd
    it "Dir.pwd should be same as `pwd`.chomp" do
      expect(Dir.pwd).to eq(`pwd`.chomp)
    end

    it "should return hooks.emailprefix if it's not empty" do
      expected = "name of repo with parent"
      double(GitCommitNotifier::Git).from_shell("git config hooks.emailprefix") { expected }
      dont_allow(Dir).pwd
      expect(GitCommitNotifier::Git.repo_name_with_parent).to eq(expected)
    end

    it "should return folder name with parent if no emailprefix and directory not ended with .git" do
      double(GitCommitNotifier::Git).from_shell("git config hooks.emailprefix") { " " }
      double(GitCommitNotifier::Git).toplevel_dir { "/home/someuser/repositories/root/myrepo" }
      expect(GitCommitNotifier::Git.repo_name_with_parent).to eq("root/myrepo")
    end

    it "should return folder name with parent without extension if no emailprefix and directory ended with .git" do
      double(GitCommitNotifier::Git).from_shell("git config hooks.emailprefix") { " " }
      double(GitCommitNotifier::Git).toplevel_dir { "/home/someuser/repositories/root/myrepo.git" }
      expect(GitCommitNotifier::Git.repo_name_with_parent).to eq("root/myrepo")
    end

    it "should return folder name with parent if no emailprefix and toplevel dir and directory not ended with .git" do
      double(GitCommitNotifier::Git).from_shell("git config hooks.emailprefix") { " " }
      double(GitCommitNotifier::Git).toplevel_dir { "" }
      double(GitCommitNotifier::Git).git_dir { "/home/someuser/repositories/root/myrepo.git" }
      expect(GitCommitNotifier::Git.repo_name_with_parent).to eq("root/myrepo")
    end

	it "should return just folder name if no emailprefix and single toplevel dir and directory not ended with .git" do
      double(GitCommitNotifier::Git).from_shell("git config hooks.emailprefix") { " " }
      double(GitCommitNotifier::Git).toplevel_dir { "" }
      double(GitCommitNotifier::Git).git_dir { "/myrepo.git" }
      expect(GitCommitNotifier::Git.repo_name_with_parent).to eq("myrepo")
    end

  end

  describe :log do
    it "should run git log with given args" do
      double(GitCommitNotifier::Git).from_shell("git log --pretty=fuller #{SAMPLE_REV}..#{SAMPLE_REV_2}") { " ok " }
      expect(GitCommitNotifier::Git.log(SAMPLE_REV, SAMPLE_REV_2)).to eq("ok")
    end
  end

  describe :branch_head do
    it "should run git rev-parse with given treeish" do
      double(GitCommitNotifier::Git).from_shell("git rev-parse #{SAMPLE_REV}") { " ok " }
      expect(GitCommitNotifier::Git.branch_head(SAMPLE_REV)).to eq("ok")
    end
  end

  describe :mailing_list_address do
    it "should run git config hooks.mailinglist" do
      double(GitCommitNotifier::Git).from_shell("git config hooks.mailinglist") { " ok " }
      expect(GitCommitNotifier::Git.mailing_list_address).to eq("ok")
    end
  end

  describe :new_empty_branch do
    it "should commit an empty branch and output nothing" do
      double(GitCommitNotifier::Git).from_shell("git rev-parse --not --branches") {
        "^#{SAMPLE_REV}\n^#{SAMPLE_REV}\n^#{SAMPLE_REV_2}" }
      double(GitCommitNotifier::Git).rev_parse("refs/heads/branch2") { SAMPLE_REV }
      double(GitCommitNotifier::Git).from_shell("git rev-list --reverse #{SAMPLE_REV} ^#{SAMPLE_REV_2}") { SAMPLE_REV }
      double(GitCommitNotifier::Git).from_shell("git rev-list --reverse ^#{SAMPLE_REV} ^#{SAMPLE_REV_2} #{SAMPLE_REV}") { "" }
      expect(GitCommitNotifier::Git.new_commits("0000000000000000000000000000000000000000", SAMPLE_REV, "refs/heads/branch2", true)).to eq([])
    end
  end

  describe :changed_files do
    it "should run git log --name-status --oneline with given args and strip out the result" do
      files = ["M       README.rdoc\n",
               "D       git_commit_notifier/Rakefile\n",
               "M       post-receive\n"]
      double(GitCommitNotifier::Git).from_shell("git log #{SAMPLE_REV}..#{SAMPLE_REV_2} --name-status --pretty=oneline -M0.5" ) { IO.read(FIXTURES_PATH + 'git_log_name_status') }
      expect(GitCommitNotifier::Git.changed_files(SAMPLE_REV, SAMPLE_REV_2)).to eq(files)
    end
  end

  describe :split_status do
    it "should split list of changed files in a hash indexed with statuses" do
      files = ["M       README.rdoc\n",
               "D       git_commit_notifier/Rakefile\n",
               "M       post-receive\n"]
      double(GitCommitNotifier::Git).from_shell("git log #{SAMPLE_REV}..#{SAMPLE_REV_2} --name-status --pretty=oneline -M0.5" ) { IO.read(FIXTURES_PATH + 'git_log_name_status') }
      output = GitCommitNotifier::Git.split_status(SAMPLE_REV, SAMPLE_REV_2)
      expect(output[:m]).to eq([ 'README.rdoc', 'post-receive' ])
      expect(output[:d]).to eq([ 'git_commit_notifier/Rakefile' ])
    end
  end


end
