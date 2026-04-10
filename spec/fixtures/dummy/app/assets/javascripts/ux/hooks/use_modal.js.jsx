const useModal = () => {
  const [open, setOpen] = React.useState(false);
  return {
    open,
    show: () => setOpen(true),
    hide: () => setOpen(false)
  };
};
