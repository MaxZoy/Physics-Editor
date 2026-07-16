# CollisionSolver.gd (Autoload)
extends Node

# 计算质点与固定斜面碰撞后的速度
# v: 碰前速度
# normal: 斜面单位法向量（指向质点一侧）
# mass: 质点质量
# restitution: 恢复系数 (0=完全非弹性, 1=完全弹性)
# 返回: 碰后速度
func solve_static_collision(v: Vector3, normal: Vector3, mass: float, restitution: float) -> Vector3:
    var n = normal.normalized()
    var vn = v.dot(n)   # 法向速度（正=远离斜面，负=冲向斜面）
    
    # 如果质点正在远离斜面，不需要处理
    if vn >= 0:
        return v
    
    # 法向分量反向 × 恢复系数
    var vn_new = -restitution * vn
    
    # 切向分量不变
    var vt = v - vn * n
    var v_new = vt + vn_new * n
    
    return v_new

# 计算动能
func kinetic_energy(v: Vector3, mass: float) -> float:
    return 0.5 * mass * v.length_squared()

# 计算动量
func momentum(v: Vector3, mass: float) -> Vector3:
    return mass * v

# 计算碰撞前后的能量损失
func collision_energy_loss(v_before: Vector3, v_after: Vector3, mass: float) -> float:
    return kinetic_energy(v_before, mass) - kinetic_energy(v_after, mass)

# 计算反弹方向（单位向量）
func reflection_direction(v: Vector3, normal: Vector3, restitution: float) -> Vector3:
    var v_new = solve_static_collision(v, normal, 1.0, restitution)  # mass 不影响方向
    return v_new.normalized() if v_new.length() > 0.001 else Vector3.ZERO

# 计算反弹角度（相对于斜面法线）
func reflection_angle(v: Vector3, normal: Vector3) -> float:
    var n = normal.normalized()
    var v_dir = v.normalized()
    return acos(abs(v_dir.dot(n)))

# ==================== 刚体旋转扩展（长方体） ====================

# 计算长方体绕质心的局部惯性张量（对角元素）
# half_size: 半边长 Vector3(hx, hy, hz)
# mass: 质量
# 返回: Vector3(Ixx, Iyy, Izz)
func compute_box_inertia(mass: float, half_size: Vector3) -> Vector3:
    var hx = half_size.x
    var hy = half_size.y
    var hz = half_size.z
    var Ixx = (1.0 / 12.0) * mass * (hy * hy + hz * hz)
    var Iyy = (1.0 / 12.0) * mass * (hx * hx + hz * hz)
    var Izz = (1.0 / 12.0) * mass * (hx * hx + hy * hy)
    return Vector3(Ixx, Iyy, Izz)

# 应用力矩冲量，更新角速度（刚体动力学）
# angular_velocity: 当前角速度（世界空间）
# basis: 物体当前的全局变换基（正交矩阵）
# local_inertia: 局部惯性对角向量（由 compute_box_inertia 得到）
# torque_impulse: 世界空间的力矩冲量（r × impulse）
# 返回: 新的角速度
func apply_angular_impulse(angular_velocity: Vector3, basis: Basis, local_inertia: Vector3, torque_impulse: Vector3) -> Vector3:
    # 将世界空间力矩冲量转换到局部空间
    var local_torque = basis.inverse() * torque_impulse
    # 除以局部惯性张量（对角矩阵的逆就是对角元素取倒数）
    local_torque = Vector3(
        local_torque.x / local_inertia.x,
        local_torque.y / local_inertia.y,
        local_torque.z / local_inertia.z
    )
    # 转回世界空间，累加到角速度
    return angular_velocity + basis * local_torque

# 更新旋转四元数和全局变换
# orientation: 当前累积旋转（Quaternion）
# angular_velocity: 当前角速度（世界空间）
# delta: 时间步长
# damping: 角速度阻尼系数（0~1，每帧乘以该值，1为无阻尼）
# max_speed: 角速度最大限制（弧度/秒）
# 返回: 新的 orientation
func update_rotation(orientation: Quaternion, angular_velocity: Vector3, delta: float, damping: float = 0.98, max_speed: float = 15.0) -> Quaternion:
    var av = angular_velocity * damping
    var speed = av.length()
    if speed > max_speed:
        av = av.normalized() * max_speed
        speed = max_speed
    if speed > 0.0001:
        var axis = av / speed
        var angle = speed * delta
        orientation = orientation * Quaternion(axis, angle)
    return orientation


