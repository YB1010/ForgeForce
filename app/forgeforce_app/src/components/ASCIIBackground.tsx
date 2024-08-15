import React from 'react';

const ASCIIBackground: React.FC = () => {
  return (
    <div className="absolute inset-0 overflow-hidden opacity-10 select-none">
      <pre className="text-yellow-300 text-xs leading-none">
        {`
█▀▀ █▀█ █▀█ █▀▀ █▀▀   █▀▀ █▀█ █▀█ █▀▀ █▀▀
█▀  █▄█ █▀▄ █▄█ ██▄   █▀  █▄█ █▀▄ █▄▄ ██▄
`.repeat(100)}
      </pre>
    </div>
  );
};

export default ASCIIBackground;