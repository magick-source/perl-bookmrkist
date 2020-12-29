$Bk = {
  _inited: false,

  add_link: function ( form_selector ) {
    if ( ! this._inited )
      return;

    console.log( { 'this': this });

    var formdata = $( form_selector ).serialize();

    return this._post( 'add-link', formdata );
  },

  _post: function( method, data ) {
    var path = this.apibase + '/' + method;

    return $.post( path, data )
      .fail( function( jqXHR, err, errorThrown ) {
        var errorobj = {};
      
        if ( jqXHR.responseJSON ) {
          eRes = jqXHR.responseJSON;

          if ( eRes.errors ) {
            for ( i in eRes.errors ) {
              var err = eRes.errors[i];
  
              if ( err.field ) {
                $(document).trigger('handle-input-field-error', err );
              } else {
                $(document).trigger('handler-api-error', err );
              }
            }
            return;
          } else {
            errorobj = {
                'type': 'apierror',
                'message': errorThrown,
              };
          }
  
          console.log({ "error": errorobj });
          // TODO: handle other types of errors
        }
      });
  },

  init: function () {
    this.apibase = sitevars.apibase;
    this._inited = true;
  }
};
$(document).ready(function() {
  $Bk.init();
});
