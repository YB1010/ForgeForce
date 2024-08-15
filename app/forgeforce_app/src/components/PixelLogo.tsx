// PixelLogo.tsx
import React, { useState } from 'react';
const styles = require('./pixelLogoAnimation.css');

const PixelLogo: React.FC = () => {
  const [isMonster, setIsMonster] = useState(false);

  const handleTransform = () => {
    setIsMonster(true);
  };

  return (
    <pre
      className={`text-xs md:text-sm lg:text-base xl:text-lg font-mono text-center ${
        isMonster ? styles['transform-to-monster'] : ''
      }`}
      onClick={handleTransform}
    >
      {`
███████╗ ██████╗ ██████╗  ██████╗ ███████╗    ███████╗ ██████╗ ██████╗  ██████╗███████╗
██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝██╔════╝
█████╗  ██║   ██║██████╔╝██║  ███╗█████╗      █████╗  ██║   ██║██████╔╝██║     █████╗  
██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝      ██╔══╝  ██║   ██║██╔══██╗██║     ██╔══╝  
██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗    ██║     ╚██████╔╝██║  ██║╚██████╗███████╗
╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚══════╝
      `}
    </pre>
  );
};

export default PixelLogo;