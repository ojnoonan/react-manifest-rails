var MainNavbar = function(props) {
  return React.createElement('nav', { className: 'navbar' },
    React.createElement('a', { href: '/' }, 'Home'),
    React.createElement('a', { href: '/notifications' }, 'Notifications'),
    React.createElement('a', { href: '/users' }, 'Users')
  );
};
