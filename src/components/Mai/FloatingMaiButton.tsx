import React, { useRef, useState } from "react";
import { motion } from "framer-motion";
import { useNavigate } from "react-router-dom";
import MaiAvatar from "./MaiAvatar";

const FloatingMaiButton: React.FC = () => {
  const constraintsRef = useRef<HTMLDivElement>(null);
  const navigate = useNavigate();
  const [dragging, setDragging] = useState(false);
  const [hovered, setHovered] = useState(false);

  return (
    <>
      <div ref={constraintsRef} className="fixed inset-0 z-40 pointer-events-none">
        <motion.button
          drag
          dragConstraints={constraintsRef}
          dragElastic={0.1}
          onDragStart={() => setDragging(true)}
          onDragEnd={() => setTimeout(() => setDragging(false), 100)}
          onClick={() => {
            if (!dragging) navigate("/");
          }}
          onMouseEnter={() => setHovered(true)}
          onMouseLeave={() => setHovered(false)}
          whileTap={{ scale: 0.9 }}
          initial={{ x: 0, y: 0 }}
          animate={{ opacity: hovered ? 1 : 0.4 }}
          transition={{ opacity: { duration: 0.2 } }}
          className="pointer-events-auto absolute right-5 w-11 h-11 rounded-full shadow-lg mai-shadow cursor-grab active:cursor-grabbing"
          style={{ touchAction: "none", top: "67vh" }}
        >
          <MaiAvatar emotion="happy" size="sm" animate={false} />
        </motion.button>
      </div>
    </>
  );
};

export default FloatingMaiButton;
