require File.join(File.dirname(__FILE__) + '/../spec_helper')

describe MpdConnection do

  describe "setup" do
    before do
      MpdConnection.class_eval do
        @mpd = nil
      end
      
      MPD.stub!(:new).and_return @mpd = mock("MPD", :connect => nil, :register_callback => nil)
      Library.stub! :current_song_callback
    end
    
    it "should get a new connection to the MPD server" do
      MPD.should_receive(:new).with("mpd", 6600).and_return @mpd
      @mpd.should_receive(:connect).with true
      
      MpdConnection.setup
    end
    
    it "should register a callback for the 'current song'" do
      @mpd.should_receive(:register_callback).with Library.method("current_song_callback"), MPD::CURRENT_SONG_CALLBACK
      MpdConnection.setup
    end
  end
  
  describe "fetch albums with artists" do
    before do
      MPD.stub!(:new).and_return @mpd = mock("MPD", :connect => nil, :register_callback => nil, :albums => ["album1"], :find => [])
      MpdConnection.setup
    end
    
    it "should fetch all albums from the server" do
      @mpd.should_receive(:albums).and_return []
      MpdConnection.fetch_albums_with_artists
    end
    
    it "should try to find the artist for each album" do
      @mpd.should_receive(:find).with "album", "album1"
      MpdConnection.fetch_albums_with_artists
    end
    
    it "should return the album + artist in the return" do
      MpdConnection.fetch_albums_with_artists.should include(["", "album1"])
    end
    
    it "should include an empty artist if we got an error while searching for the artist" do
      @mpd.stub!(:find).and_raise RuntimeError.new
      MpdConnection.fetch_albums_with_artists.should include(["", "album1"])
    end
    
    it "should use the artist name if we found one" do
      @mpd.stub!(:find).and_return [mock("Song", :artist => "me")]
      MpdConnection.fetch_albums_with_artists.should include(["me", "album1"])
    end
  end
  
  describe "execute" do
    before do
      MPD.stub!(:new).and_return @mpd = mock("MPD", :connect => nil, :register_callback => nil)
      MpdConnection.setup
      
      @mpd.stub! :action
    end
    
    it "should execute the given action on the mpd object" do
      @mpd.should_receive :action
      MpdConnection.execute :action
    end
    
    it "should return the result of the MPD method call" do
      @mpd.stub!(:action).and_return "result!"
      MpdConnection.execute(:action).should == "result!"
    end
  end
  
  describe "play album" do
    before do
      MPD.stub!(:new).and_return @mpd = mock("MPD", :connect => nil, :register_callback => nil, :clear => nil, :add => nil, :play => nil)
      MpdConnection.setup
      
      @song1 = MPD::Song.new
      { "artist" => "me1", "title" => "song1", "album" => "hits1", "track" => "2", "file" => "file1" }.each { |k, v| @song1[k] = v }
      @song2 = MPD::Song.new
      { "artist" => "me2", "title" => "song2", "album" => "hits2", "track" => "1", "file" => "file2" }.each { |k, v| @song2[k] = v }
      @mpd.stub!(:find).and_return @new_songs = [@song1, @song2]
    end
    
    it "should clear the playlist" do
      @mpd.should_receive :clear
      MpdConnection.play_album "my album"
    end
    
    it "should look for all songs matching the album exactly" do
      @mpd.should_receive(:find).with("album", "my album").and_return []
      MpdConnection.play_album "my album"
    end
    
    it "should order the file list by track number" do
      @new_songs.should_receive(:sort_by).and_return []
      MpdConnection.play_album "my album"
    end
    
    it "should add all files to the playlist" do
      [@song1, @song2].each { |s| @mpd.should_receive(:add).with s.file }
      MpdConnection.play_album "my album"
    end
    
    it "should start playback" do
      @mpd.should_receive :play
      MpdConnection.play_album "my album"
    end
  end
  
  describe "find albums for" do
    before do
      MPD.stub!(:new).and_return @mpd = mock("MPD", :connect => nil, :register_callback => nil, :search => [])
      MpdConnection.setup
      
      @song = MPD::Song.new
      { "artist" => "me", "title" => "song", "album" => "hits" }.each { |k, v| @song[k] = v }
    end
    
    it "should use the MPD server to search for matches in title, artist and album" do
      @mpd.should_receive(:search).with("artist", "query").and_return []
      @mpd.should_receive(:search).with("album", "query").and_return []
      @mpd.should_receive(:search).with("title", "query").and_return []
      
      MpdConnection.find_albums_for("query").should be_empty
    end
    
    it "should return every matched album only once" do
      @mpd.stub!(:search).and_return [@song]
      MpdConnection.find_albums_for("query").should == ["hits"]
    end

    it "should return nothing if we get an error" do
      @mpd.stub!(:search).and_raise RuntimeError.new
      MpdConnection.find_albums_for("query").should be_empty
    end
  end
end