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
      // most likely I'll refactor this to have an api file
      // and move all the object handling to the theme specific
      // files
      $('#form-add-link-submit').attr("disabled", true);
      $('#form-add-link-submit-loader').show;
    
      $('#form--add-link .form-control')
        .removeClass('is-invalid');

      $Bk.add_link( this ).always(function () {
          $('#form-add-link-submit').attr("disabled", false);
          $('#form-add-link-submit-loader').hide;
          console.log('Got here!!');
        });

      event.preventDefault();
      return true;
    });

});

