# -*- coding: utf-8; mode: ruby; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- vim:fenc=utf-8:filetype=ruby:et:sw=2:ts=2:sts=2

require File.expand_path('../../../spec_helper', __FILE__)
require 'tempfile'
require 'nokogiri'
require 'git_commit_notifier'

describe GitCommitNotifier::DiffToHtml do

  describe :chmod do
    it "should not raise anything and set mode from stats mode" do
      file = Tempfile.new('stattest')
      file.close
      expect do
        File.chmod(File.stat(file.path).mode, file.path)
      end.not_to raise_error
    end
  end

  describe :generate_file_link do
    it "should generate proper url for stash" do
      diff = GitCommitNotifier::DiffToHtml.new(
              "link_files" => "stash",
              "stash" => {
                "path" => "http://example.com/projects/TEST",
                "repository" => "TESTREPO"
              })

      double(GitCommitNotifier::Git).rev_type(REVISIONS[1]) { "commit" }
      double(GitCommitNotifier::Git).rev_type(REVISIONS[2]) { "commit" }
      double(GitCommitNotifier::Git).new_commits(anything, anything, anything, anything) { [REVISIONS[1]] }
      [REVISIONS[1]].each do |rev|
        double(GitCommitNotifier::Git).show(rev, :ignore_whitespace => 'all') { IO.read(FIXTURES_PATH + 'git_show_' + rev) }
        dont_allow(GitCommitNotifier::Git).describe(rev) { IO.read(FIXTURES_PATH + 'git_describe_' + rev) }
      end

      diff.diff_between_revisions REVISIONS[1], REVISIONS[2], 'testproject', 'refs/heads/master'

      expect(diff.result.size).to eq(1) # one result for each of the commits

      diff.result.each do |html|
        expect(html).not_to include('@@') # diff correctly processed
      end

      expect(diff.generate_file_link("x/file1.html")).to \
        eq("<a href='http://example.com/projects/TEST/repos/TESTREPO/browse/x/file1.html?at=a4629e707d80a5769f7a71ca6ed9471015e14dc9'>x/file1.html</a>")
    end
  end

  describe :lines_are_sequential? do
    before(:all) do
      @diff_to_html = GitCommitNotifier::DiffToHtml.new
    end

    it "should be true if left line numbers are sequential" do
      expect(@diff_to_html).to be_lines_are_sequential({
        :added => 2,
        :removed => 2
      }, {
        :added => 3,
        :removed => 6
      })
    end

    it "should be true if right line numbers are sequential" do
      expect(@diff_to_html).to be_lines_are_sequential({
        :added => 2,
        :removed => 2
      }, {
        :added => 7,
        :removed => 3
      })
    end

    it "should be false unless line numbers are sequential" do
      expect(@diff_to_html).not_to be_lines_are_sequential({
        :added => 2,
        :removed => 2
      }, {
        :added => 4,
        :removed => 6
      })
    end

    it "should be true if left line numbers are sequential (right are nil)" do
      expect(@diff_to_html).to be_lines_are_sequential({
        :added => 2,
        :removed => 2
      }, {
        :added => 3,
        :removed => nil
      })
    end

    it "should be true if right line numbers are sequential (left are nil)" do
      expect(@diff_to_html).to be_lines_are_sequential({
        :added => nil,
        :removed => 2
      }, {
        :added => 7,
        :removed => 3
      })
    end

    it "should be false unless line numbers are sequential (nils)" do
      expect(@diff_to_html).not_to be_lines_are_sequential({
        :added => nil,
        :removed => nil
      }, {
        :added => 4,
        :removed => 6
      })
    end
  end

  describe :unique_commits_per_branch? do
    it "should be false unless specified in config" do
      diff = GitCommitNotifier::DiffToHtml.new
      expect(diff).not_to be_unique_commits_per_branch
    end

    it "should be false if specified as false in config" do
      diff = GitCommitNotifier::DiffToHtml.new({ 'unique_commits_per_branch' => false })
      expect(diff).not_to be_unique_commits_per_branch
    end

    it "should be true if specified as true in config" do
      diff = GitCommitNotifier::DiffToHtml.new({ 'unique_commits_per_branch' => true })
      expect(diff).to be_unique_commits_per_branch
    end
  end

  it "multiple commits" do
    double(GitCommitNotifier::Git).changed_files('7e4f6b4', '4f13525') { [] }
    double(GitCommitNotifier::Git).rev_type(REVISIONS.first) { "commit" }
    double(GitCommitNotifier::Git).rev_type(REVISIONS.last) { "commit" }
    double(GitCommitNotifier::Git).new_commits(anything, anything, anything, anything) { REVISIONS.reverse }
    REVISIONS.each do |rev|
      double(GitCommitNotifier::Git).show(rev, :ignore_whitespace => 'all') { IO.read(FIXTURES_PATH + 'git_show_' + rev) }
      dont_allow(GitCommitNotifier::Git).describe(rev) { IO.read(FIXTURES_PATH + 'git_describe_' + rev) }
    end

    diff = GitCommitNotifier::DiffToHtml.new
    diff.diff_between_revisions REVISIONS.first, REVISIONS.last, 'testproject', 'refs/heads/master'

    expect(diff.result.size).to eq(5) # one result for each of the commits

    diff.result.each do |html|
      expect(html).not_to include('@@') # diff correctly processed
    end

    # second commit - 51b986619d88f7ba98be7d271188785cbbb541a0
    hp = Nokogiri::HTML diff.result[1][:html_content]
    expect((hp/"table").size).to eq(3) # 3 files updated
    (hp/"table"/"tr"/"td").each do |td|
      if td.inner_html =~ /create_btn/
        cols = td.parent.search('td')
        expect(['405', '408', '']).to include(cols[0].inner_text) # line 405 changed
      end
    end

    # third commit - dce6ade4cdc2833b53bd600ef10f9bce83c7102d
    hp = Nokogiri::HTML diff.result[2][:html_content]
    expect((hp/"h2").size).to eq(6) # 6 files in commit
    expect((hp/"table").size).to eq(4) # 4 files updated
    expect((hp/"h2")[1].inner_text).to eq('Added binary file railties/doc/guides/source/images/icons/callouts/11.png')
    expect((hp/"h2")[2].inner_text).to eq('Deleted binary file railties/doc/guides/source/icons/up.png')
    expect((hp/"h2")[3].inner_text).to eq('Deleted file railties/doc/guides/source/icons/README')
    expect((hp/"h2")[4].inner_text).to eq('Added file railties/doc/guides/source/images/icons/README')

    # fourth commit
    hp = Nokogiri::HTML diff.result[3][:html_content]
    expect((hp/"table").size).to eq(1) # 1 file updated

    # fifth commit
    hp = Nokogiri::HTML diff.result[4][:html_content]
    expect((hp/"table").size).to eq(2) # 2 files updated - one table for each of the files
    (hp/"table"/"tr"/"td").each do |td|
      if td.inner_html == "require&nbsp;'iconv'"
        # first added line in changeset a4629e707d80a5769f7a71ca6ed9471015e14dc9
        expect(td.parent.search('td')[0].inner_text).to eq('') # left
        expect(td.parent.search('td')[1].inner_text).to eq('2') # right
        expect(td.parent.search('td')[2].inner_html).to eq("require&nbsp;'iconv'") # change
      end
    end
  end

  it "should get good diff when new branch created" do
    first_rev, last_rev = %w[ 0000000000000000000000000000000000000000 ff037a73fc1094455e7bbf506171a3f3cf873ae6 ]
    double(GitCommitNotifier::Git).rev_type(first_rev) { "commit" }
    double(GitCommitNotifier::Git).rev_type(last_rev) { "commit" }
    double(GitCommitNotifier::Git).new_commits(anything, anything, anything, anything) { [ 'ff037a73fc1094455e7bbf506171a3f3cf873ae6' ] }
    %w[ ff037a73fc1094455e7bbf506171a3f3cf873ae6 ].each do |rev|
      double(GitCommitNotifier::Git).show(rev, :ignore_whitespace => 'all') { IO.read(FIXTURES_PATH + 'git_show_' + rev) }
      dont_allow(GitCommitNotifier::Git).describe(rev) { IO.read(FIXTURES_PATH + 'git_describe_' + rev) }
    end
    diff = GitCommitNotifier::DiffToHtml.new
    diff.diff_between_revisions(first_rev, last_rev, 'tm-admin', 'refs/heads/rvm')
    expect(diff.result.size).to eq(1)
    hp = Nokogiri::HTML diff.result.first[:html_content]
    expect((hp/"table").size).to eq(1)
    expect((hp/"tr.r").size).to eq(1)
  end

  describe :message_map do
    before(:each) do
      @diff = GitCommitNotifier::DiffToHtml.new
    end

    it "should do message mapping" do
      double(@diff).do_message_integration("msg") { "msg2" }
      double(@diff).do_message_map("msg2") { "msg3" }
      expect(@diff.message_map("msg")).to eq("msg3")
    end

    it "should do message integration" do
      double(@diff).do_message_integration("msg") { "msg2" }
      double(@diff).do_message_map("msg2") { "msg3" }
      expect(@diff.message_map("msg")).to eq("msg3")
    end
  end

  describe :do_message_integration do
    before(:each) do
      @config = Hash.new
      @diff = GitCommitNotifier::DiffToHtml.new(@config)
    end

    it "should do nothing unless message_integration config section exists" do
      double.proxy(nil).respond_to?(:each_pair)
      dont_allow(@diff).message_replace!
      expect(@diff.do_message_integration('yu')).to eq('yu')
    end
    it "should pass MESSAGE_INTEGRATION through message_replace!" do
      @config['message_integration'] = {
        'mediawiki' => 'http://example.com/wiki', # will rework [[text]] to MediaWiki pages
        'redmine' => 'http://redmine.example.com' # will rework refs #123, #125 to Redmine issues
      }
      expect(@diff.do_message_integration("[[text]] refs #123, #125")).to eq("<a href=\"http://example.com/wiki/text\">[[text]]</a> refs <a href=\"http://redmine.example.com/issues/123\">#123</a>, <a href=\"http://redmine.example.com/issues/125\">#125</a>")
    end
  end

  describe :old_commit? do
    before(:each) do
      @config = Hash.new
      @diff_to_html = GitCommitNotifier::DiffToHtml.new(@config)
    end

    it "should be false unless skip_commits_older_than set" do
      expect(@diff_to_html.old_commit?(Hash.new)).to be false
    end

    it "should be false if skip_commits_older_than less than zero" do
      @config['skip_commits_older_than'] = '-7'
      expect(@diff_to_html.old_commit?(Hash.new)).to be false
    end

    it "should be false if skip_commits_older_than is equal to zero" do
      @config['skip_commits_older_than'] = 0
      expect(@diff_to_html.old_commit?(Hash.new)).to be false
    end

    it "should be false if commit is newer than required by skip_commits_older_than" do
      @config['skip_commits_older_than'] = 1
      expect(@diff_to_html.old_commit?({:date => (Time.now - 1).to_s})).to be false
    end

    it "should be true if commit is older than required by skip_commits_older_than" do
      @config['skip_commits_older_than'] = 1
      expect(@diff_to_html.old_commit?({:date => (Time.now - 2 * GitCommitNotifier::DiffToHtml::SECS_PER_DAY).to_s})).to be_truthy
    end
  end
end
