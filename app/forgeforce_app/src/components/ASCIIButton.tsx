import React, { useState } from 'react';
import Link from 'next/link';
import { cn } from '@/lib/utils';

interface ASCIIButtonProps {
  href: string;
  children?: React.ReactNode;
  className?: string;
  onClick?: () => void;
  disabled?: boolean;
}

const ASCIIButton: React.FC<ASCIIButtonProps> = ({ href, children, className, onClick }) => {
  const [hovered, setHovered] = useState(false);

  const text = String(children);
  const textLength = text.length;
  const horizontalBorder = hovered ? '═'.repeat(textLength + 2) : '─'.repeat(textLength + 2);

  // Change the corner and side borders based on hover state
  const topLeftCorner = hovered ? '╔' : '┌';
  const bottomLeftCorner = hovered ? '╚' : '└';
  const topRightCorner = hovered ? '╗' : '┐';
  const bottomRightCorner = hovered ? '╝' : '┘';
  const verticalBorder = hovered ? '║' : '│';

  return (
    <Link
      href={href}
      className="group inline-block font-mono text-yellow-300 hover:text-yellow-100 transition-colors duration-300"
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      <pre className="whitespace-pre m-0 p-0 inline-block text-yellow-300 group-hover:text-yellow-500">
        {`${topLeftCorner}${horizontalBorder}${topRightCorner}\n`}
        {`${verticalBorder} `}
        <button
          type="button"
          className={cn(
            'inline-block bg-transparent border-none p-0 m-0 font-mono text-yellow-300 group-hover:text-yellow-500',
            className
          )}
          onClick={onClick}
          aria-label={text} // Add an accessible label
        >
          {text}
        </button>
        {` ${verticalBorder}\n`}
        {`${bottomLeftCorner}${horizontalBorder}${bottomRightCorner}`}
      </pre>
    </Link>
  );
};

export default ASCIIButton;