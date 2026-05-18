import React, { useRef } from "react";
import { Canvas, useFrame } from "@react-three/fiber";
import { OrbitControls, Environment } from "@react-three/drei";
import * as THREE from "three";

/* Aesthetic breast mesh with elegant anatomical visualization */
const BreastMesh: React.FC<{ side: "L" | "R" }> = ({ side }) => {
  const groupRef = useRef<THREE.Group>(null);

  useFrame(({ clock }) => {
    if (groupRef.current) {
      groupRef.current.rotation.y = Math.sin(clock.getElapsedTime() * 0.25) * 0.1;
    }
  });

  const flip = side === "R" ? -1 : 1;

  // Elegant teardrop profile via LatheGeometry
  const breastGeo = React.useMemo(() => {
    const controlPoints = [
      [0, 0.44],
      [0.05, 0.42],
      [0.16, 0.38],
      [0.34, 0.26],
      [0.50, 0.10],
      [0.57, -0.04],
      [0.54, -0.18],
      [0.44, -0.30],
      [0.26, -0.40],
      [0.10, -0.45],
      [0, -0.47],
    ];
    const spline = new THREE.SplineCurve(
      controlPoints.map(([x, y]) => new THREE.Vector2(x, y))
    );
    const pts = spline.getPoints(48);
    const geo = new THREE.LatheGeometry(pts, 56);
    const pos = geo.attributes.position;
    for (let i = 0; i < pos.count; i++) {
      const y = pos.getY(i);
      const sag = y < 0 ? Math.abs(y) * 0.05 : 0;
      pos.setY(i, y - sag);
      pos.setZ(i, pos.getZ(i) + y * 0.04);
    }
    geo.computeVertexNormals();
    return geo;
  }, []);

  // Areola - a smooth convex disc that sits on the breast surface
  const areolaGeo = React.useMemo(() => {
    const profile = [
      new THREE.Vector2(0, 0.02),
      new THREE.Vector2(0.04, 0.018),
      new THREE.Vector2(0.08, 0.014),
      new THREE.Vector2(0.12, 0.008),
      new THREE.Vector2(0.15, 0.003),
      new THREE.Vector2(0.17, 0),
    ];
    return new THREE.LatheGeometry(profile, 32);
  }, []);

  // Refined nipple
  const nippleGeo = React.useMemo(() => {
    const profile = [
      new THREE.Vector2(0, 0),
      new THREE.Vector2(0.05, 0.0),
      new THREE.Vector2(0.055, 0.015),
      new THREE.Vector2(0.048, 0.05),
      new THREE.Vector2(0.035, 0.075),
      new THREE.Vector2(0.018, 0.09),
      new THREE.Vector2(0, 0.095),
    ];
    return new THREE.LatheGeometry(profile, 20);
  }, []);

  // Elegant duct network with organic curves
  const ducts = React.useMemo(() => {
    const paths: { main: THREE.Vector3[]; branches: THREE.Vector3[][] }[] = [];
    const count = 7;
    for (let i = 0; i < count; i++) {
      const angle = (i / count) * Math.PI * 2 + (Math.random() - 0.5) * 0.25;
      const r = 0.28 + Math.random() * 0.16;

      const main = [
        new THREE.Vector3(0, 0.36, 0),
        new THREE.Vector3(Math.cos(angle) * r * 0.25 * flip, 0.18, Math.sin(angle) * r * 0.25),
        new THREE.Vector3(Math.cos(angle) * r * 0.5 * flip, 0.02 - Math.random() * 0.06, Math.sin(angle) * r * 0.5),
        new THREE.Vector3(Math.cos(angle) * r * 0.78 * flip, -0.14 - Math.random() * 0.08, Math.sin(angle) * r * 0.78),
        new THREE.Vector3(Math.cos(angle) * r * flip, -0.26 - Math.random() * 0.1, Math.sin(angle) * r),
      ];

      const branches: THREE.Vector3[][] = [];
      if (Math.random() > 0.35) {
        const brAngle = angle + (Math.random() - 0.5) * 0.7;
        const brR = r * 0.75;
        branches.push([
          main[2].clone(),
          new THREE.Vector3(Math.cos(brAngle) * brR * 0.7 * flip, -0.12 - Math.random() * 0.06, Math.sin(brAngle) * brR * 0.7),
          new THREE.Vector3(Math.cos(brAngle) * brR * flip, -0.22 - Math.random() * 0.08, Math.sin(brAngle) * brR),
        ]);
      }
      if (Math.random() > 0.6) {
        const brAngle2 = angle + (Math.random() - 0.5) * 0.5;
        branches.push([
          main[3].clone(),
          new THREE.Vector3(Math.cos(brAngle2) * r * 0.9 * flip, -0.28 - Math.random() * 0.06, Math.sin(brAngle2) * r * 0.9),
        ]);
      }
      paths.push({ main, branches });
    }
    return paths;
  }, [side, flip]);

  // Lobules at branch ends
  const lobules = React.useMemo(() => {
    const lobs: THREE.Vector3[] = [];
    ducts.forEach((d) => {
      lobs.push(d.main[d.main.length - 1]);
      d.branches.forEach((br) => lobs.push(br[br.length - 1]));
    });
    return lobs;
  }, [ducts]);

  return (
    <group ref={groupRef} position={[0, -0.04, 0]}>
      {/* Outer skin - soft blush pink translucent */}
      <mesh geometry={breastGeo}>
        <meshPhysicalMaterial
          color="#f2c8d4"
          transparent
          opacity={0.32}
          roughness={0.38}
          metalness={0.0}
          clearcoat={0.5}
          clearcoatRoughness={0.25}
          transmission={0.15}
          thickness={0.8}
          side={THREE.DoubleSide}
          depthWrite={false}
        />
      </mesh>

      {/* Inner warm glow layer */}
      <mesh geometry={breastGeo} scale={0.94}>
        <meshPhysicalMaterial
          color="#f5d4de"
          transparent
          opacity={0.1}
          roughness={1}
          side={THREE.BackSide}
        />
      </mesh>

      {/* Areola - rosy burgundy */}
      <mesh geometry={areolaGeo} position={[0, 0.355, 0]}>
        <meshStandardMaterial color="#b86878" roughness={0.65} side={THREE.DoubleSide} />
      </mesh>

      {/* Nipple - deeper rose */}
      <mesh geometry={nippleGeo} position={[0, 0.36, 0]}>
        <meshStandardMaterial color="#a86070" roughness={0.5} />
      </mesh>

      {/* Duct network - gradient color from nipple to lobes */}
      {ducts.map((duct, i) => {
        const curve = new THREE.CatmullRomCurve3(duct.main);
        return (
          <group key={i}>
            <mesh>
              <tubeGeometry args={[curve, 20, 0.014, 8, false]} />
              <meshPhysicalMaterial
                color="#d4889c"
                transparent
                opacity={0.65}
                roughness={0.3}
                clearcoat={0.3}
                clearcoatRoughness={0.2}
              />
            </mesh>
            {/* Thinner sub-branches */}
            {duct.branches.map((br, j) => {
              const brCurve = new THREE.CatmullRomCurve3(br);
              return (
                <mesh key={j}>
                  <tubeGeometry args={[brCurve, 12, 0.009, 6, false]} />
                  <meshPhysicalMaterial
                    color="#cc8898"
                    transparent
                    opacity={0.45}
                    roughness={0.35}
                    clearcoat={0.2}
                  />
                </mesh>
              );
            })}
          </group>
        );
      })}

      {/* Lobule clusters - soft glowing spheres */}
      {lobules.map((pos, i) => (
        <group key={`lob-${i}`} position={pos}>
          {/* Central glow */}
          <mesh>
            <sphereGeometry args={[0.04, 12, 12]} />
            <meshPhysicalMaterial
              color="#e8a8bc"
              transparent
              opacity={0.3}
              roughness={0.6}
              emissive="#e8a8bc"
              emissiveIntensity={0.15}
            />
          </mesh>
          {/* Clustered acini */}
          {[0, 1, 2, 3, 4].map((j) => {
            const theta = (j / 5) * Math.PI * 2;
            const pr = 0.025 + Math.random() * 0.01;
            return (
              <mesh
                key={j}
                position={[Math.cos(theta) * 0.03, (Math.random() - 0.5) * 0.03, Math.sin(theta) * 0.03]}
              >
                <sphereGeometry args={[pr, 8, 8]} />
                <meshPhysicalMaterial
                  color="#dca0b4"
                  transparent
                  opacity={0.55}
                  roughness={0.45}
                  clearcoat={0.2}
                />
              </mesh>
            );
          })}
        </group>
      ))}
    </group>
  );
};

interface BreastModelProps {
  side: "L" | "R";
  status: "normal" | "risk" | "attention";
}

const statusLabels: Record<string, { label: string; color: string }> = {
  normal: { label: "未见异常", color: "text-emerald-600" },
  risk: { label: "损伤风险", color: "text-amber-500" },
  attention: { label: "需要关注", color: "text-red-500" },
};

const BreastModel: React.FC<BreastModelProps> = ({ side, status }) => {
  const info = statusLabels[status];
  return (
    <div className="flex flex-col items-center gap-1">
      <div className="w-[150px] h-[150px] rounded-2xl overflow-hidden"
        style={{ background: "linear-gradient(180deg, hsl(340 30% 96%) 0%, hsl(343 25% 93%) 100%)" }}
      >
        <Canvas camera={{ position: [0, 0.08, 1.7], fov: 36 }} gl={{ antialias: true, alpha: true }}>
          <ambientLight intensity={0.5} />
          <directionalLight position={[3, 4, 3]} intensity={0.6} color="#ffe8e8" />
          <directionalLight position={[-2, 2, -1]} intensity={0.3} color="#fdd8e0" />
          <pointLight position={[0, -0.2, 1.2]} intensity={0.25} color="#fcc8d4" distance={3} />
          <BreastMesh side={side} />
          <OrbitControls
            enableZoom={false}
            enablePan={false}
            minPolarAngle={Math.PI * 0.25}
            maxPolarAngle={Math.PI * 0.75}
          />
        </Canvas>
      </div>
      <span className="text-xs text-muted-foreground">{side === "L" ? "左侧" : "右侧"}</span>
      <span className={`text-xs font-semibold ${info.color}`}>● {info.label}</span>
    </div>
  );
};

export default React.memo(BreastModel);
