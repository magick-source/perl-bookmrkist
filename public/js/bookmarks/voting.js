$(document).ready(function () {
  $('.bookmark_to_vote.vote-type-like').click(function (e) {
    e.preventDefault();
    cast_vote( this, 'like' );
  });
  $('.bookmark_to_vote.vote-type-dislike').click(function (e) {
    e.preventDefault();
    cast_vote( this, 'dislike' );
  });
  $('.bookmark_to_vote.vote-type-love').click(function (e) {
    e.preventDefault();
    cast_vote( this, 'love' );
  });
  $('.bookmark_to_vote.vote-type-hate').click(function (e) {
    e.preventDefault();
    cast_vote( this, 'hate' );
  });
  $('.bookmark_to_vote.vote-type-spam').click(function (e) {
    e.preventDefault();
    cast_vote( this, 'spam' );
  });

  $('.login_to_vote').click(function (e) {
    e.preventDefault();
    $('#loginToast').addClass('show').removeClass('hide');
    setTimeout(function() {
        $('#loginToast').addClass('hide').removeClass('show');    
      },3000)
  });
  $('#loginToast .btn-close').click(function() {
    $('#loginToast').addClass('hide').removeClass('show'); 
  });
  $('.bookmark_vote_disable, .bookmark_voted').click(function (e) {
    e.preventDefault();
  });
});

function cast_vote ( vote_link, vote_type ) {
  var card_id = $(vote_link).closest('.card')[0].id;

  if ( card_id != undefined ) {
    var bookmark_id = card_id.replace("bookmark-","");

    $Bk.vote( bookmark_id, vote_type, $BkVToken ).done(function (resdata) {
        if ( resdata.done != 1 ) {
          return;
        }

        data = resdata.data;
        if ( data.remove_vote !== undefined ) {
          cls=".vote-type-"+data.remove_vote + " i";
          $(vote_link).closest('.card').find(cls)
            .removeClass("fas")
            .addClass("far");
        }
        if ( data.add_vote !== undefined ) {
          cls=".vote-type-"+data.add_vote + " i";
          $(vote_link).closest('.card').find(cls)
            .removeClass("far")
            .addClass("fas");
        }
        console.log("got here"); 
        console.log( data );
      }).always(function () {
        console.log("Always get here");
      });
  }
}
