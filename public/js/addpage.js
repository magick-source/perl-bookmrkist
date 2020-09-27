$(document).ready(function () {

  // Handle tags in the addpage
  $('#input-url-tags').selectize({
      maxItems: 10,
      scoreField: 'score',
      valueField: 'tag',
      labelField: 'tag',
      create: function(input) {
          return {
            tag:   input,
            score: 1
          }
        },
      load: function(query, callback) {
          //TODO: fetch the tags from the server
          return callback();
        }
    });

  // Submit the add form as ajax
  $('#form-add-link').submit(function ( event ) {
      $('#form-add-link-submit').attr("disabled", true);
      $('#form-add-link-submit-loader').show;
    
      var formdata = $(this).serialize();

      $.post(sitevars.apibase + '/add-link', function (data) {
          console.log( data );
          
        }).fail( function( jqXHR, error, errorThrown ) {
          var errorobj = {};
          if (jqXHR.responseJSON && jqXHR.responseJSON.error) {
            errorobj = jqXHR.responseJSON.error;
          } else {
            errorobj = {
                'type': 'fatal',
                'message': errorThrown
              };
          }
          console.log( 'post failed!' );
          console.log( errorobj );

        }).always( function() {
          $('#form-add-link-submit').attr("disabled", false);
          $('#form-add-link-submit-loader').hide;
        });

      event.preventDefault();
      return true;
    });

});

