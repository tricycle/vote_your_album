// On Load
$(function() {

  function resizeBody() {
    $("section.music").css({ height: $(window).height() - $("body > header").outerHeight(true) - 70 });
    $("section.music .list").css({ height: $("section.music").innerHeight() - $("section.music header").height() - 30 });
    $("section.music .overlay").css({ height: $("section.music").outerHeight(true) });

    $("section.upcoming").css({ height: $("section.music").height() - $("section.updates").outerHeight(true) });
    $("section.upcoming .list").css({ height: $("section.upcoming").innerHeight() - $("section.upcoming header").height() - 30 });
  };

  $(window).resize(function() {
    resizeBody();
  });
  resizeBody();

  // Volume Slider definition
  $("#slider").slider({
    animate: true,
    stop: function() {
      $.post("/volume/" + $(this).slider("option", "value"));
    }
  });

  // Fetch songs when clicking on the album
  $("section.music article").live("click", function() {
    var album = $(this);
    $(".song_spinner", album).show();
    $("section.music article .songs:visible").hide("blind");

    getSongs(album);
    return false;
  });

  // Basic modal dialog settings
  $("#modal-dialog").dialog({
    autoOpen: false,
    modal: true,
    width: 500
  });

  // Drag & Drop definitions
  $("section.upcoming").droppable({
    scope: "adding",
    hoverClass: "over",
    drop: function(event, ui) {
      var album = ui.draggable;

      if (album.children(".songs").is(":visible")) {
        $("#modal-dialog")
          .dialog("option", "title", album.attr("artist") + " - " + album.attr("title"))
          .dialog("option", "buttons", {
            "Add selected tracks": function() {
              $("#add-album").ajaxSubmit({
                success: function(list) {
                  $("section.upcoming .list").html(list);
                }
              });

              $(this).dialog("close");
            }
          });

        $.getJSON("/songs/" + album.attr("ref"), function(list) {
          $("#modal-dialog").dialog("open");
          renderSongs($("#modal-dialog"), album.attr("ref"), list, true)
        });
      }
      else {
        $.post("/add", { album_id: album.attr("ref") }, function(list) {
          $("section.upcoming .list").html(list);
        });
      }
    }
  });

  $("section.music").droppable({
    scope: "removing",
    hoverClass: "over",
    drop: function(event, ui) {
      $.post("/remove/" + ui.draggable.attr("ref"), function(list) {
        $("section.upcoming .list").html(list);
      });
    }
  });

  $("section.upcoming .list").live("mouseover", function() {
    $("section.upcoming .deleteable").draggable($.extend(drag_options, {
      scope: "removing"
    }));
  });

  // Show updates when clicking on a nomination
  $("section.upcoming article").live("click", function() {
    var nomination = $(this);

    if (nomination.children(".songs").is(":visible")) {
      nomination.children(".songs").hide("blind");
    }
    else {
      $("section.upcoming article .songs:visible").hide("blind");
      nomination.children(".songs").show("blind", {}, "normal", function() {
        $("section.upcoming .list").scrollTo(nomination, 500, {
          offset: -50
        });
      });
    }

    return false;
  });

  // Click events that update the status of the application
  $(".control").click(function() {
    return executeAndUpdate("/control/" + $(this).attr("ref"));
  });

  // Click Events that update the 'upcoming list'
  $.each(["up", "down"], function() {
    var action = this;
    $("." + action).live("click", function() {
      $.post("/" + action + "/" + $(this).attr("ref"), function(list) {
        $("section.upcoming .list").html(list);
      });

      return false
    });
  });

  // (Un-) Star an album
  $(".star").live("click", function() {
    var star = $(this).hide();
    var spinner = $(this).siblings(".star-spinner").show();

    $.ajax({
      type: "POST",
      url: star.attr("href"),
      data: "",
      success: function() {
        spinner.hide();
        star.toggleClass("favourite").show();
      }
    });

    return false;
  });

  // Submit the form with AJAX
  $("#search").ajaxForm({
    dataType: "json",
    beforeSend: function() {
      $("section.music .overlay").show();
    },
    success: function(list) {
      updateList(list);
    }
  });

  // Search
  $("#query").delayedObserver(function() {
    if ($(this).val().length == 0) {
      getList("starred");
    }
    else if ($(this).val().length > 2) {
      $("#search").submit();
    }
  }, 0.3);

  // Starred music
  $("a.starred").click(function() {
    $("#query").val("");
    getList("starred");
    return false;
  });

  // Shuffle
  $("a.shuffle").click(function() {
    $("#query").val("shuffle");
    $("#search").submit();
    return false;
  });

  // Character quick links
  $("a.artist-index").click(function() {
    $("#query").val("artist:" + $(this).attr("ref"));
    $("#search").submit();
    return false;
  });

  // Tag listings
  $("a.tag").live("click", function() {
    $("#query").val('tag:' + $(this).attr("ref"));
    $("#search").submit();
    return false;
  });

  // Update the library
  $("a.update-lib").click(function() {
    if (confirm("Did u add your music to the server?\nAre u ready to wait about half a minute?\nPromise u won't blaim Tom if this doesn't work?\nThen go on!")) {
      $.post("/library/update", "");
    }

    return false;
  });

  // Initial page update to load the lists and the status
  getList("starred");
  getUpcoming();
  getStatus();
  getUpdates();
});

// Drag definitions
var drag_options = {
  helper: "clone",
  opacity: 0.8,
  zIndex: 99,
  appendTo: "body"
}

/*
 * Requests an update of the available albums and updates the list
 */
function getList(type) {
  $("section.music .overlay").show();

  $.getJSON("/music/" + type, function(list) {
    updateList(list);
    return false;
  });
}

/*
 * Fetch the albums songs and render them inside the songs element
 */
function getSongs(album) {
  $.getJSON("/songs/" + album.attr("ref"), function(list) {
    $(".song_spinner").hide();

    renderSongs(album.children(".songs"), album.attr("ref"), list);
    album.children(".songs").show("blind", {}, "normal", function() {
      $("section.music .list").scrollTo(album, 500, {
        offset: -50
      });
    });
  });
}

/*
 * Requests an update of the upcoming albums and updates the list
 */
function getUpcoming() {
  $.get("/upcoming", function(list) {
    $("section.upcoming .list").html(list);
  });
  setTimeout("getUpcoming();", 8000);
}

/*
 * Get the latest status from the server to update the main controls.
 */
function getStatus() {
  $.getJSON("/status", mainControls);
  setTimeout("getStatus();", 10000);
}

/*
 * Requests the list of updates
 */
function getUpdates() {
  $.get("/updates", function(list) {
    $("section.updates .list").html(list);
  });
  setTimeout("getUpdates();", 7000);
}

/*
 * Takes the list of albums and initializes iterative renderding.
 */
var albumList = [];
function updateList(albums) {
  var list = $("section.music .list");
  list.children().draggable("disable");
  list.html("");

  albumList = albums;
  $("section.music .overlay").hide();

  if (!_.isEmpty(albumList)) setTimeout("appendAlbumsIteratively()", 1);
}

/*
 * Renders 20 albums at once and then 'flushes' them out.
 */
function appendAlbumsIteratively() {
  var list = $("section.music .list");

  var albums = _.first(albumList, 20);
  albumList = _.rest(albumList, 20);

  $.each(albums, function() {
    list.append(albumElement(this));
  });
  list.children().draggable($.extend(drag_options, {
    scope: "adding"
  }));

  if (!_.isEmpty(albumList)) setTimeout("appendAlbumsIteratively()", 1);
}

/*
 * Render the songs inside the given element
 */
function renderSongs(songs, album_id, list, allowSelection) {
  var container = songs;
  container.html("");

  if (allowSelection) {
    var form = $('<form action="/add" method="post" id="add-album"></form>');
    form.append('<input type="hidden" name="album_id" value="' + album_id + '" />');

    songs.append(form);
    container = form;
  }

  $.each(list, function() {
    container.append(songElement(this, allowSelection));
  });
}

/*
 * Returns an album element.
 */
function albumElement(album) {
  return ' \
    <article class="album" ref="' + album.id + '" artist="' + album.artist + '" title="' + album.name + '" title="Click to show songs"> \
      <div class="header"> \
        <img class="song_spinner" src="/images/spinner.gif" /> \
        <div class="info"> \
          <img class="art" ' + (album.art != null ? ('src="/images/albums/' + album.art + '"') : '') + ' /> \
          <p>' + album.artist + '</p> \
          <p>' + album.name + '</p> \
        </div> \
        <aside class="voting"> \
          <a class="star' + (album.favourite ? " favourite" : "") + '" href="/star/' + album.id + '" title="Damn awesome stuff! Show it to me all the time"></a> \
          <img class="star-spinner" src="/images/circling-ball.gif" /> \
        </aside> \
      </div> \
      <aside class="tags">' +
        _(album.tags).map(function(tag) {
          return ' <a href="search?q=tag:' + tag + '" class="tag" ref="' + tag + '">' + tag + '</a>';
        })
      + '</aside> \
      <aside class="songs"></aside> \
    </article> \
  ';
}

function songElement(song, insertCheckbox) {
  return ' \
    <p> \
      ' + (insertCheckbox ? '<input type="checkbox" name="songs[]" value="' + song.id + '" checked="checked">' : '') + ' \
      <span>(' + song.track + ') ' + song.title + '</span> \
      ' + (insertCheckbox ? ' - ' : '') + ' \
      <time>' + song.length + '</time> \
    </p> \
  ';
}

/*
 * Update the main controls (at the top of the page) according to the received status
 */
function mainControls(data) {
  $("header section.controls").toggleClass("playing", data.playing);
  $("#slider").slider("option", "value", data.volume);
  $("#art").removeAttr("src");

  if (data.playing) {
    $("#current").html(data.current_album);
    if (data.current_art) $("#art").attr("src", "/images/albums/" + data.current_art);

    var song = data.current_song
    $("#song").html("(" + song.track + ") " + song.artist + " - " + song.title);
    $("#time").html(data.time + " (" + data.total + ")");
    $("#nominator").html("by " + data.nominated_by);

    $("header article .info .score").html(data.score);
    $("header article .info").attr("class", "info " + data.score_class);

    if (data.voteable) {
      $("header article footer .voting").show();
      $("header article footer .voting a").attr("ref", data.id);
    }
    else {
      $("header article footer .voting").hide();
    }
  }
  else {
    $("#current").html("");
    $("#song").html("");
    $("#time").html("");
    $("#nominator").html("");
    $("header article footer .voting").hide();
  }
}

/*
 * Helper function that executes a POST request with the given URL
 */
function executeAndUpdate(url) {
  $.ajax({
    type: "POST",
    dataType: "json",
    url: url,
    success: mainControls
  });

  return false;
}
