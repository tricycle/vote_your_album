require File.join(File.dirname(__FILE__) + '/../spec_helper')

describe MpdProxy do

  describe "setup" do
    before do
      MpdProxy.class_eval do
        @mpd = nil
      end

      MPD.stub!(:new).and_return @mpd = mock("MPD", :connect => nil, :register_callback => nil)
      MpdProxy.stub! :current_song=
      MpdProxy.stub! :volume=
    end

    it "should get a new connection to the MPD server with the specified parameters" do
      MPD.should_receive(:new).with("mpd server", 1234).and_return @mpd
      @mpd.should_receive(:connect).with false

      MpdProxy.setup "mpd server", 1234
    end

    it "should connect to the server using callbacks when the callbacks arg is true" do
      @mpd.should_receive(:connect).with true
      MpdProxy.setup "mpd server", 1234, true
    end

    it "should register a callback for the 'current song'" do
      @mpd.should_receive(:register_callback).with MpdProxy.method(:current_song=), MPD::CURRENT_SONG_CALLBACK
      MpdProxy.setup "server", 1234
    end

    it "should register a callback for the 'volume'" do
      @mpd.should_receive(:register_callback).with MpdProxy.method(:volume=), MPD::VOLUME_CALLBACK
      MpdProxy.setup "server", 1234
    end

    it "should register a callback for the elapsed time" do
      @mpd.should_receive(:register_callback).with MpdProxy.method(:time=), MPD::TIME_CALLBACK
      MpdProxy.setup "server", 1234
    end
  end

  describe "execute" do
    before do
      MPD.stub!(:new).and_return @mpd = mock("MPD", :connect => nil, :register_callback => nil)
      MpdProxy.setup "server", 1234
      @mpd.stub! :action
    end

    it "should execute the given action on the mpd object" do
      @mpd.should_receive :action
      MpdProxy.execute :action
    end

    it "should return the result of the MPD method call" do
      @mpd.stub!(:action).and_return "result!"
      MpdProxy.execute(:action).should == "result!"
    end
  end

  describe "find songs for" do
    before do
      MPD.stub!(:new).and_return @mpd = mock("MPD", :connect => nil, :register_callback => nil)
      MpdProxy.setup "server", 1234
      @mpd.stub!(:find).and_return "songs"
    end

    it "should ask the mpd object for the songs" do
      @mpd.should_receive(:find).with "album", "hits"
      MpdProxy.find_songs_for "hits"
    end

    it "should return the result of the find" do
      MpdProxy.find_songs_for("hits").should == "songs"
    end
  end

  describe "volume accessor" do
    before do
      WebsocketDispatcher.stub! :write_json
    end

    it "should return the volume of the class variable" do
      MpdProxy.class_eval do
        @volume = 41
      end

      MpdProxy.volume.should == 41
    end

    it "should update the volume variable of the class" do
      MpdProxy.volume = 53
      MpdProxy.volume.should == 53
    end

    it "should broadcast the volume with the websocket dispatcher" do
      WebsocketDispatcher.should_receive(:write_json).with({ :volume => 53 })
      MpdProxy.volume = 53
    end
  end

  describe "change volume to" do
    before do
      MPD.stub!(:new).and_return @mpd = mock("MPD", :connect => nil, :register_callback => nil)
      MpdProxy.setup "server", 1234
    end

    it "should change the volume on the MPD server" do
      @mpd.should_receive(:volume=).with 41
      MpdProxy.change_volume_to 41
    end
  end

  describe "current song accessor" do
    before do
      MpdProxy.stub! :play_next

      WebsocketDispatcher.stub! :write_json
    end

    it "should return the value of the class variable" do
      MpdProxy.class_eval do
        @current_song = "song"
      end

      MpdProxy.current_song.should == "song"
    end

    it "should return false for 'playing?' if we dont have a current song" do
      MpdProxy.class_eval do
        @current_song = nil
      end

      MpdProxy.should_not be_playing
    end

    it "should return true for 'playing?' if we have a current song" do
      MpdProxy.class_eval do
        @current_song = "song"
      end

      MpdProxy.should be_playing
    end

    it "should assign the song in the param" do
      MpdProxy.current_song = "artist - title"
      MpdProxy.current_song.should == "artist - title"
    end

    it "should not play the next album if we get something other than nil" do
      MpdProxy.should_not_receive :play_next
      MpdProxy.current_song = "something"
    end

    it "should play the next album if we get nil" do
      MpdProxy.should_receive :play_next
      MpdProxy.current_song = nil
    end

    it "should broadcast the new song with the websocket dispatcher" do
      WebsocketDispatcher.should_receive(:write_json).with({ :current_song => "artist - title" })
      MpdProxy.current_song = "artist - title"
    end
  end

  describe "time accessor" do
    before do
      WebsocketDispatcher.stub! :write_json
    end

    it "should return the saved time (seconds)" do
      MpdProxy.class_eval do
        @time = 123
      end

      MpdProxy.time.should == 123
    end

    it "should set the time variable to the calculated time remaining" do
      MpdProxy.send :time=, 12, 43
      MpdProxy.time.should == 31
    end

    it "should set a 0 value if we get an error" do
      MpdProxy.send :time=, 0, 0
      MpdProxy.time.should == 0
    end

    it "should broadcast the formatted time with the websocket dispatcher" do
      WebsocketDispatcher.should_receive(:write_json).with({ :time => 31.to_time })
      MpdProxy.send :time=, 12, 43
    end
  end

  describe "play next" do
    before do
      MPD.stub!(:new).and_return @mpd = mock("MPD", :connect => nil, :register_callback => nil)
      MpdProxy.setup "server", 1234

      @mpd.stub! :clear
      @mpd.stub! :add
      @mpd.stub! :play

      @next = Nomination.new
      @next.stub! :update
      Nomination.stub!(:active).and_return [@next]
    end

    it "should do nothing if we dont have an upcoming album" do
      Nomination.stub!(:active).and_return []
      @next.should_not_receive :update
      MpdProxy.play_next
    end

    it "should clear the playlist before we add the new stuff" do
      @mpd.should_receive :clear
      MpdProxy.play_next
    end

    it "should update the status of the nomination to 'played'" do
      Time.stub!(:now).and_return "time"
      @next.should_receive(:update).with :status => "played", :played_at => "time"
      MpdProxy.play_next
    end

    it "should add all songs associated with the nomination" do
      @next.stub!(:songs).and_return [song = Song.new(:file => "path")]
      @mpd.should_receive(:add).with "path"
      MpdProxy.play_next
    end

    it "should start playback" do
      @mpd.should_receive :play
      MpdProxy.play_next
    end
  end

  describe "status" do
    before do
      MpdProxy.stub!(:playing?).and_return false
    end

    it "should return the volume" do
      MpdProxy.stub!(:volume).and_return 32
      MpdProxy.status("me")[:volume].should == 32
    end

    it "should contain the 'playing' flag" do
      MpdProxy.stub!(:playing?).and_return false
      MpdProxy.status("me")[:playing].should be_false
    end

    it "should not include the information about the current album if we are not playing anything" do
      MpdProxy.stub!(:playing?).and_return false
      MpdProxy.status("me").should_not have_key(:current_album)
    end

    describe "currently playing an album" do
      before do
        MpdProxy.stub!(:playing?).and_return true
        MpdProxy.stub!(:time).and_return 123

        @song = MPD::Song.new
        { "artist" => "me", "title" => "song" }.each { |k, v| @song[k] = v }
        MpdProxy.stub!(:current_song).and_return @song

        @album = Album.new(:artist => "c", :name =>  "three")
        Nomination.stub!(:current).and_return @nomination = Nomination.new(:album => @album)
        @nomination.stub!(:down_votes_necessary).and_return 1
      end

      it "should include the name of the current album" do
        MpdProxy.status("me")[:current_album].should == "c - three"
      end

      it "should include the information of the current song" do
        MpdProxy.status("me")[:current_song].should == @song
      end

      it "should include the time remaining for the song" do
        MpdProxy.status("me")[:time].should == "-02:03"
      end

      it "should include the number of necessary (remaining) forces" do
        MpdProxy.status("me")[:down_votes_necessary].should == 1
      end

      it "should include whether we can force" do
        @nomination.stub!(:can_be_forced_by?).and_return false
        MpdProxy.status("me")[:forceable].should be_false
      end

      it "should have a flag saying if the user can rate this album (nomination)" do
        @nomination.stub!(:can_be_rated_by?).and_return false
        MpdProxy.status("me")[:rateable].should be_false
      end
    end
  end
end
