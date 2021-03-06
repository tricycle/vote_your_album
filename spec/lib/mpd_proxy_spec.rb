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
      MpdProxy.stub!(:mpd).and_return @mpd = mock("MPD")
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

  describe "songs for" do
    before do
      MpdProxy.stub!(:mpd).and_return @mpd = mock("MPD")
      @mpd.stub!(:songs).and_return "songs"
    end

    it "should ask the mpd object for the songs" do
      @mpd.should_receive(:songs).with "abc/hits"
      MpdProxy.songs_for "abc/hits"
    end

    it "should return the result of the find" do
      MpdProxy.songs_for("abc/hits").should == "songs"
    end
  end

  describe "volume accessor" do
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
  end

  describe "change volume to" do
    before do
      MpdProxy.stub!(:mpd).and_return @mpd = mock("MPD")
    end

    it "should change the volume on the MPD server" do
      @mpd.should_receive(:volume=).with 41
      MpdProxy.change_volume_to 41
    end
  end

  describe "current song accessor" do
    before do
      MpdProxy.stub! :play_next
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
  end

  describe "time accessor" do
    it "should set the time variable to the calculated time remaining" do
      MpdProxy.send :time=, 12, 43
      MpdProxy.time.should == 31
    end

    it "should set a 0 value if we get an error" do
      MpdProxy.send :time=, 0, 0
      MpdProxy.time.should == 0
    end
  end

  describe "play next" do
    before do
      MpdProxy.stub!(:mpd).and_return @mpd = mock("MPD")
      @mpd.stub! :clear => true, :add => true, :play => true

      @album = Album.new
      Album.stub!(:nominate_similar).and_return @nomination = Nomination.new(:album => @album)
      @nomination.stub! :play => nil

      Nomination.stub_chain(:current, :album).and_return @current = Album.new

      Update.stub! :log
    end

    it "should clear the playlist before we add the new stuff" do
      @mpd.should_receive :clear
      MpdProxy.play_next
    end

    it "should start playback (if we get some songs)" do
      @album.stub!(:songs).and_return [song = Song.new(:file => "path")]
      @mpd.should_receive :play
      MpdProxy.play_next
    end

    describe "with a nomination" do
      before do
        @next = Nomination.new(:user => User.new)
        @next.stub! :play => nil

        Nomination.stub!(:active).and_return [@next]
      end

      it "should play the nomination" do
        @next.should_receive(:play).with @mpd
        MpdProxy.play_next
      end

      it "should reset the random tracks counter to 1" do
        MpdProxy.instance_variable_set :@random_tracks, 99
        MpdProxy.play_next
        MpdProxy.instance_variable_get(:@random_tracks).should == 1
      end
    end

    describe "without a nomination" do
      before do
        MpdProxy.instance_variable_set :@random_tracks, 1

        Nomination.stub!(:active).and_return []
        @songs = [Song.new(:file => "path1"), Song.new(:file => "path2"), Song.new(:file => "path3"), Song.new(:file => "path4")]
      end

      it "should find a similar album" do
        Album.should_receive(:nominate_similar).with(@album, 1).and_return @nomination
        MpdProxy.play_next
      end

      it "should increase the random tracks count" do
        MpdProxy.play_next
        MpdProxy.instance_variable_get(:@random_tracks).should == 2
      end

      it "should not add random tracks if it's after 7PM (9AM UTC)" do
        Time.stub_chain(:now, :utc, :+).and_return time = mock("Time", :hour => 19)

        Album.should_not_receive :get
        @mpd.should_not_receive :play

        MpdProxy.play_next
      end
    end
  end

  describe "mpd accessor" do
    before do
      MPD.stub!(:new).and_return @mpd = mock("MPD", :connect => nil, :connected? => true, :register_callback => nil, :status => nil)
      MpdProxy.setup "server", 1234
    end

    it "should not connect again, if we are connected" do
      @mpd.should_not_receive :connect
      MpdProxy.execute :status
    end

    it "should reconnect if we lost connection" do
      @mpd.stub! :connected? => false
      @mpd.should_receive :connect

      MpdProxy.execute :status
    end
  end
end