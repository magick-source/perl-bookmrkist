$(document).on('handle-input-field-error', function (event, err) {
  var field = err.field;
  var selector = '.form-control[name="'+field+'"]';
  $( selector )
    .closest('.form-group')
    .find('.form-control')
    .addClass('is-invalid');

  console.log({'on': 'error-handler', 'event': event, 'err': err });
});
