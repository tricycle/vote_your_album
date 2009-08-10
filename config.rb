# -----------------------------------------------------------------------------------
# Development environment
# -----------------------------------------------------------------------------------
configure :development do
  DataMapper.setup(:default, "mysql://localhost/vote_your_album_dev")
  
  MpdConnection.setup "mpd", 6600
end

# -----------------------------------------------------------------------------------
# Production environment
# -----------------------------------------------------------------------------------
configure :production do
  DataMapper.setup(:default, {
    :adapter  => "mysql",
    :database => "vote_your_album_prod",
    :username => "album_vote",
    :password => "EhbwVkKD5OdNY",
    :host     => "mysql"
  })
  
  MpdConnection.setup "mpd", 6600, true
end

# -----------------------------------------------------------------------------------
# General config
# -----------------------------------------------------------------------------------
NECESSARY_FORCE_VOTES = 3 # number of votes necessary to force the next album