var NotificationsShow = function(props) {
  var modal = useModal();

  return React.createElement('div', { className: 'notification-show' },
    React.createElement('h1', null, props.title),
    React.createElement(PrimaryButton, { onClick: modal.show }, 'Dismiss'),
    React.createElement('p', null, formatDate(props.createdAt))
  );
};
