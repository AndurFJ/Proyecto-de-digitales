----------------------------------------------------------------------------------
-- PROYECTO FINAL: SISTEMA DE SEGURIDAD Y JUEGO
-- VERSIÓN FINAL V4 (Corrección de letras en Display SUBE/BAJA/OH/FAIL)
-- FPGA: Basys 3
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ===============================================================================
-- MÓDULO 1: DEBOUNCER (Filtro anti-rebote)
-- DESCRIPCIÓN:
-- Este módulo elimina el ruido mecánico (rebotes) generado al presionar un pulsador.
-- Utiliza un contador para verificar que la señal se mantenga estable por un tiempo
-- definido (5ms) antes de cambiar la salida.
-- ===============================================================================
entity debouncer is
    Port ( 
        clk     : in STD_LOGIC;  -- Señal de reloj del sistema (ej. 100 MHz)
        reset   : in STD_LOGIC;  -- Reset asíncrono (activo en alto)
        btn_in  : in STD_LOGIC;  -- Entrada del botón físico (señal con ruido/rebotes)
        btn_out : out STD_LOGIC  -- Salida del botón procesada (señal limpia y estable)
    );
end debouncer;

architecture Behavioral of debouncer is
    -- Configuración del tiempo de filtrado.
    -- Cálculo: 500,000 ciclos * 10 ns (si reloj es 100MHz) = 5 ms.
    constant UMBRAL_CONTADOR : integer := 500_000; -- 5ms
    
    -- Señales para sincronizar la entrada asíncrona con el reloj (evita metaestabilidad)
    signal btn_sync_0, btn_sync_1 : std_logic := '0';
    
    -- Contador para medir la duración de la señal entrante
    signal contador : integer range 0 to UMBRAL_CONTADOR := 0;
    
    -- Registro que almacena el último estado validado (limpio) del botón
    signal estado_estable : std_logic := '0';

begin
    process(clk, reset)
    begin
        if reset = '1' then
            -- Reinicio de todas las señales internas y salidas
            btn_sync_0 <= '0'; 
            btn_sync_1 <= '0';
            contador <= 0; 
            estado_estable <= '0'; 
            btn_out <= '0';
        elsif rising_edge(clk) then
            -- 1. Etapa de Sincronización:
            -- Se pasa la entrada por dos flip-flops para alinearla con el reloj del sistema
            btn_sync_0 <= btn_in;
            btn_sync_1 <= btn_sync_0;
            
            -- 2. Lógica de Detección de Cambio:
            -- Si la entrada sincronizada difiere del estado estable actual, hay un posible cambio
            if (btn_sync_1 /= estado_estable) then
                contador <= contador + 1; -- Se incrementa el contador
                
                -- Si el contador alcanza el umbral, el cambio se considera válido (no es ruido)
                if contador >= UMBRAL_CONTADOR then
                    estado_estable <= btn_sync_1; -- Actualiza el estado estable al nuevo valor
                    contador <= 0;                -- Reinicia el contador para el próximo evento
                end if;
            else
                -- Si la entrada vuelve a ser igual al estado estable antes de llegar al umbral,
                -- se considera ruido y se reinicia el contador.
                contador <= 0;
            end if;
            
            -- 3. Actualización de la salida
            btn_out <= estado_estable;
        end if;
    end process;
end Behavioral;

-- ===============================================================================
-- MÓDULO 2: ALMACENAMIENTO DE CLAVE
-- DESCRIPCIÓN:
-- Este módulo actúa como una memoria o registro. Permite al usuario programar
-- una nueva contraseña de 4 bits cuando el sistema está en "modo configuración".
-- La clave se guarda solo cuando se detecta un flanco de subida en 'confirmar'.
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity almacenamiento_clave is
    Port ( 
        clk              : in STD_LOGIC;  -- Reloj del sistema
        reset            : in STD_LOGIC;  -- Reset para borrar la clave guardada
        modo_config      : in STD_LOGIC;  -- Habilitador: '1' permite cambiar la clave
        nueva_clave      : in STD_LOGIC_VECTOR (3 downto 0); -- Entrada de datos (switches)
        confirmar        : in STD_LOGIC;  -- Señal de disparo para guardar (botón)
        clave_almacenada : out STD_LOGIC_VECTOR (3 downto 0); -- Salida constante de la clave guardada
        clave_programada : out STD_LOGIC  -- Bandera: indica si ya existe una clave válida ('1')
    );
end almacenamiento_clave;

architecture Behavioral of almacenamiento_clave is
    -- Registro interno para mantener la clave en memoria
    signal clave_reg      : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    
    -- Registro para la bandera de estado
    signal programada     : STD_LOGIC := '0';
    
    -- Señal auxiliar para detectar el flanco de subida del botón 'confirmar'
    signal confirmar_prev : STD_LOGIC := '0';

begin
    process(clk, reset)
    begin
        if reset = '1' then
            -- Borrado de seguridad: clave a 0 y bandera a 'no programada'
            clave_reg <= "0000"; 
            programada <= '0'; 
            confirmar_prev <= '0';
            
        elsif rising_edge(clk) then
            -- Almacenamos el estado anterior de 'confirmar' para detectar cambios
            confirmar_prev <= confirmar;

            -- Lógica de escritura:
            -- 1. El modo configuración debe estar activo (modo_config = '1').
            -- 2. Se detecta un flanco de subida en confirmar (actual='1' y anterior='0').
            --    Esto asegura que se guarde solo una vez aunque el botón siga presionado.
            if modo_config = '1' and confirmar = '1' and confirmar_prev = '0' then
                clave_reg <= nueva_clave; -- Guarda el valor de los switches
                programada <= '1';        -- Activa la bandera de "Clave Lista"
            end if;
        end if;
    end process;

    -- Asignación de los registros internos a los puertos de salida
    clave_almacenada <= clave_reg;
    clave_programada <= programada;

end Behavioral;

-- ===============================================================================
-- MÓDULO 3: CONTADOR DE INTENTOS
-- DESCRIPCIÓN:
-- Este módulo gestiona la seguridad limitando el número de pruebas permitidas.
-- Inicia con 3 intentos. Cada pulso en 'intento_fallido' resta 1 al contador.
-- Si llega a 0, activa la señal 'sin_intentos' para bloquear el sistema.
-- Se puede restablecer a 3 intentos si se ingresa una clave correcta.
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity contador_intentos is
    Port ( 
        clk                : in STD_LOGIC;
        reset              : in STD_LOGIC;
        intento_fallido    : in STD_LOGIC; -- Pulso de entrada cuando la clave es incorrecta
        reiniciar_contador : in STD_LOGIC; -- Pulso para recargar los intentos (ej. al acertar)
        intentos_restantes : out STD_LOGIC_VECTOR (1 downto 0); -- Salida visual (3, 2, 1, 0)
        sin_intentos       : out STD_LOGIC -- Bandera de bloqueo ('1' cuando contador es 0)
    );
end contador_intentos;

architecture Behavioral of contador_intentos is
    -- Inicializamos el contador en "11" (3 en decimal) para dar 3 vidas al usuario
    signal contador : unsigned(1 downto 0) := "11";
    
    -- Señales auxiliares para detección de flancos de subida
    signal intento_prev, reiniciar_prev : STD_LOGIC := '0';
begin
    process(clk, reset)
    begin
        if reset = '1' then
            -- Reinicio general: vuelve a 3 intentos y limpia detectores de flanco
            contador <= "11"; 
            intento_prev <= '0'; 
            reiniciar_prev <= '0';
            
        elsif rising_edge(clk) then
            -- Actualización de estados previos para detectar flancos
            intento_prev <= intento_fallido;
            reiniciar_prev <= reiniciar_contador;
            
            -- PRIORIDAD 1: Reiniciar intentos
            -- Si se recibe la orden de reinicio (flanco de subida), recarga a 3.
            if reiniciar_contador = '1' and reiniciar_prev = '0' then
                contador <= "11";
                
            -- PRIORIDAD 2: Restar intento
            -- Si hubo un fallo (flanco de subida) Y el contador no está ya en 0.
            elsif intento_fallido = '1' and intento_prev = '0' and contador /= "00" then
                contador <= contador - 1;
            end if;
        end if;
    end process;

    -- Conversión del valor interno unsigned a vector lógico para la salida
    intentos_restantes <= std_logic_vector(contador);
    
    -- Lógica combinacional para la bandera de bloqueo:
    -- Se activa ('1') solo si el contador ha llegado a cero ("00").
    sin_intentos <= '1' when contador = "00" else '0';

end Behavioral;
-- ===============================================================================
-- MÓDULO 4: TEMPORIZADOR DE BLOQUEO
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- DESCRIPCIÓN:
-- Este módulo implementa una penalización de tiempo. Cuando se activa la señal 
-- 'iniciar_bloqueo', el sistema entra en un estado de bloqueo durante un tiempo 
-- definido (por defecto 30 segundos).
-- Utiliza la frecuencia del reloj (CLK_FREQ) para contar segundos reales.
entity temporizador_bloqueo is
    Generic ( 
        CLK_FREQ       : integer := 100_000_000; -- Frecuencia del reloj (100 MHz para Basys 3)
        TIEMPO_BLOQUEO : integer := 30           -- Duración de la penalización en segundos
    );
    Port ( 
        clk             : in STD_LOGIC;
        reset           : in STD_LOGIC;
        iniciar_bloqueo : in STD_LOGIC; -- Señal de disparo (viene del control de intentos)
        bloqueado       : out STD_LOGIC; -- Bandera de estado: '1' mientras dura la cuenta regresiva
        tiempo_restante : out STD_LOGIC_VECTOR (5 downto 0) -- Salida visual de los segundos restantes
    );
end temporizador_bloqueo;

architecture Behavioral of temporizador_bloqueo is
    -- Contador grande para medir 1 segundo exacto (Divisor de frecuencia)
    -- Se necesitan 27 bits para contar hasta 100 millones (2^27 = ~134M)
    signal contador_clk : unsigned(26 downto 0) := (others => '0');
    
    -- Registro que lleva la cuenta regresiva de los segundos (30, 29, 28...)
    signal segundos     : unsigned(5 downto 0) := (others => '0');
    
    -- Bandera interna de estado (indica si el temporizador está corriendo)
    signal en_bloqueo   : STD_LOGIC := '0';
    
    -- Detector de flanco para la señal de inicio
    signal iniciar_prev : STD_LOGIC := '0';
    
    -- Constante para saber cuándo ha pasado 1 segundo (0 a 99,999,999)
    constant TICKS_POR_SEG : integer := CLK_FREQ - 1;

begin
    process(clk, reset)
    begin
        if reset = '1' then
            -- Reinicio total del sistema
            contador_clk <= (others => '0'); 
            segundos <= (others => '0');
            en_bloqueo <= '0'; 
            iniciar_prev <= '0';
            
        elsif rising_edge(clk) then
            -- Detección de flanco de subida para activar el bloqueo
            iniciar_prev <= iniciar_bloqueo;
            
            -- 1. INICIO DEL BLOQUEO
            if iniciar_bloqueo = '1' and iniciar_prev = '0' then
                en_bloqueo <= '1';                      -- Activa la bandera de bloqueo
                segundos <= to_unsigned(TIEMPO_BLOQUEO, 6); -- Carga el tiempo (30s)
                contador_clk <= (others => '0');        -- Reinicia el contador de ciclos
            
            -- 2. MANTENIMIENTO DEL BLOQUEO (Cuenta regresiva)
            elsif en_bloqueo = '1' then
                -- Verifica si ha pasado 1 segundo real
                if contador_clk = TICKS_POR_SEG then
                    contador_clk <= (others => '0'); -- Reinicia cuenta de ciclos
                    
                    -- Decrementa los segundos o termina el bloqueo
                    if segundos > 0 then 
                        segundos <= segundos - 1; 
                    else 
                        en_bloqueo <= '0'; -- Tiempo cumplido, libera el sistema
                    end if;
                else
                    -- Incrementa contador de ciclos hasta llegar a 1 segundo
                    contador_clk <= contador_clk + 1;
                end if;
            end if;
        end if;
    end process;

    -- Asignación de salidas
    bloqueado <= en_bloqueo;
    tiempo_restante <= std_logic_vector(segundos);

end Behavioral;

-- ===============================================================================
-- MÓDULO 5: VERIFICACIÓN DE CLAVE (Con Cooldown de 1 Segundo)
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- DESCRIPCIÓN:
-- Este módulo es el cerebro de la validación. Implementa una Máquina de Estados Finitos (FSM)
-- para comparar la clave ingresada con la almacenada.
-- CARACTERÍSTICAS CLAVE:
-- 1. Cooldown de Error: Si la clave es incorrecta, obliga al sistema a esperar 1 segundo
--    antes de aceptar un nuevo intento (evita ataques de fuerza bruta o rebotes rápidos).
-- 2. Visualización de Éxito: Si la clave es correcta, mantiene la señal de éxito por 2 segundos.
entity verificacion_clave is
    Port ( 
        clk             : in STD_LOGIC;
        reset           : in STD_LOGIC;
        verificar       : in STD_LOGIC; -- Botón para intentar validar la clave
        bloqueado       : in STD_LOGIC; -- Señal que impide validar si el sistema está penalizado
        clave_ingresada : in STD_LOGIC_VECTOR (3 downto 0); -- Switches actuales
        clave_correcta  : in STD_LOGIC_VECTOR (3 downto 0); -- Clave guardada en memoria
        acceso_concedido: out STD_LOGIC; -- Salida de éxito (abre la cerradura/LED verde)
        acceso_denegado : out STD_LOGIC; -- Pulso de error (resta una vida/LED rojo)
        verificando     : out STD_LOGIC  -- Estado de depuración
    );
end verificacion_clave;

architecture Behavioral of verificacion_clave is
    -- Definición de los estados de la FSM
    type estado_t is (IDLE, VERIFICANDO_ST, CORRECTO, INCORRECTO, COOLDOWN_ERROR);
    signal estado_actual : estado_t := IDLE;
    
    -- Señales auxiliares
    signal verificar_prev : STD_LOGIC := '0'; -- Para detectar flanco de botón
    signal concedido      : STD_LOGIC := '0'; -- Registro interno de éxito
    signal denegado_reg   : STD_LOGIC := '0'; -- Registro interno de error
    
    -- Temporizador único reutilizable (para medir 1s de error o 2s de éxito)
    signal contador_tiempo : unsigned(27 downto 0) := (others => '0');
    
    -- Constantes de tiempo (basadas en reloj de 100 MHz)
    constant TICKS_2_SEG : integer := 200_000_000; -- Tiempo de visualización de éxito
    constant TICKS_1_SEG : integer := 100_000_000; -- Tiempo de espera tras error (Cooldown)
    
begin
    process(clk, reset)
    begin
        if reset = '1' then
            -- Reinicio de la máquina de estados y contadores
            estado_actual <= IDLE; 
            verificar_prev <= '0'; 
            concedido <= '0'; 
            denegado_reg <= '0';
            contador_tiempo <= (others => '0');
            
        elsif rising_edge(clk) then
            verificar_prev <= verificar;
            
            case estado_actual is
                -- ESTADO 1: ESPERA
                when IDLE =>
                    concedido <= '0'; 
                    denegado_reg <= '0';
                    contador_tiempo <= (others => '0');
                    
                    -- Condición de inicio: Flanco de subida en 'verificar' Y sistema no bloqueado
                    if verificar = '1' and verificar_prev = '0' and bloqueado = '0' then
                        estado_actual <= VERIFICANDO_ST;
                    end if;
                
                -- ESTADO 2: COMPARACIÓN
                when VERIFICANDO_ST =>
                    if clave_ingresada = clave_correcta then
                        estado_actual <= CORRECTO; 
                        concedido <= '1'; 
                        contador_tiempo <= (others => '0');
                    else
                        -- Si falla, pasamos al estado de error
                        estado_actual <= INCORRECTO;
                        denegado_reg <= '1'; 
                    end if;
                
                -- ESTADO 3: ÉXITO (Mantiene la salida activa un tiempo)
                when CORRECTO =>
                    if contador_tiempo < TICKS_2_SEG then
                        contador_tiempo <= contador_tiempo + 1; 
                        concedido <= '1'; -- Mantiene el LED verde/motor encendido
                    else
                        concedido <= '0'; 
                        estado_actual <= IDLE; -- Regresa a espera
                    end if;
                
                -- ESTADO 4: ERROR (Pulso rápido)
                when INCORRECTO =>
                    -- Este estado dura solo 1 ciclo de reloj.
                    -- Su función es enviar un pulso único al contador de vidas.
                    estado_actual <= COOLDOWN_ERROR;
                    denegado_reg <= '0'; -- Apagamos la señal de error inmediatamente
                    contador_tiempo <= (others => '0');

                -- ESTADO 5: ENFRIAMIENTO (Cooldown)
                when COOLDOWN_ERROR =>
                    -- Esperamos 1 segundo sin aceptar nuevas entradas.
                    -- Esto previene que el usuario presione botones a lo loco tras fallar.
                    if contador_tiempo < TICKS_1_SEG then
                        contador_tiempo <= contador_tiempo + 1;
                    else
                        estado_actual <= IDLE; -- Ya puede volver a intentar
                    end if;
                    
            end case;
        end if;
    end process;
    
    -- Asignación de salidas
    acceso_concedido <= concedido;
    acceso_denegado <= denegado_reg; -- Dura 1 ciclo (usar para restar vidas)
    
    -- Indicador visual (opcional) para saber cuándo la máquina está procesando
    verificando <= '1' when estado_actual = VERIFICANDO_ST else '0';
    
end Behavioral;

-- ===============================================================================
-- MÓDULO 6: VISUALIZACIÓN DISPLAY (CONTROL DE 7 SEGMENTOS)
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- DESCRIPCIÓN:
-- Este módulo se encarga de mostrar la información al usuario en el display de 7 segmentos.
-- Tiene dos modos de funcionamiento:
-- 1. MODO NORMAL: Muestra cuántos intentos le quedan al usuario (0, 1, 2 o 3).
-- 2. MODO BLOQUEO: Muestra una cuenta regresiva de los segundos de penalización.
-- Utiliza multiplexación temporal para controlar los 4 dígitos con un solo bus de datos.
entity visualizacion_display is
    Port ( 
        clk            : in STD_LOGIC;
        reset          : in STD_LOGIC;
        bloqueado      : in STD_LOGIC; -- Señal de control: '1' para mostrar temporizador
        intentos       : in STD_LOGIC_VECTOR (1 downto 0); -- Entrada de intentos (0-3)
        tiempo_bloqueo : in STD_LOGIC_VECTOR (5 downto 0); -- Entrada de tiempo (0-60s)
        seg            : out STD_LOGIC_VECTOR (6 downto 0); -- Cátodos (a,b,c,d,e,f,g)
        an             : out STD_LOGIC_VECTOR (3 downto 0)  -- Ánodos (selección de dígito)
    );
end visualizacion_display;

architecture Behavioral of visualizacion_display is
    -- Contador para generar la frecuencia de refresco de los displays.
    -- Usamos los bits más altos para dividir la frecuencia de 100MHz.
    signal refresh_counter : unsigned(19 downto 0) := (others => '0');
    
    -- Selector de 2 bits para activar uno de los 4 ánodos (00, 01, 10, 11)
    signal display_select : STD_LOGIC_VECTOR(1 downto 0);
    
    -- Señales internas para almacenar qué número va en cada posición
    signal digit0, digit1, digit2, digit3, digit_actual : STD_LOGIC_VECTOR(3 downto 0);
    
    -- FUNCIÓN: DECODIFICADOR BCD A 7 SEGMENTOS
    -- Convierte un número de 4 bits en el código de 7 segmentos (lógica negativa: 0 enciende)
    function num_to_7seg(num : STD_LOGIC_VECTOR(3 downto 0)) return STD_LOGIC_VECTOR is
    begin
        case num is
            -- "gfedcba" (formato estándar)
            when "0000" => return "0000001"; -- 0 (todos on menos g)
            when "0001" => return "1001111"; -- 1
            when "0010" => return "0010010"; -- 2
            when "0011" => return "0000110"; -- 3
            when "0100" => return "1001100"; -- 4
            when "0101" => return "0100100"; -- 5
            when "0110" => return "0100000"; -- 6
            when "0111" => return "0001111"; -- 7
            when "1000" => return "0000000"; -- 8
            when "1001" => return "0000100"; -- 9
            when others => return "1111111"; -- OFF (Apaga todo)
        end case;
    end function;

begin
    -- PROCESO 1: DIVISOR DE FRECUENCIA (REFRESCO)
    process(clk, reset)
    begin
        if reset = '1' then 
            refresh_counter <= (others => '0');
        elsif rising_edge(clk) then 
            refresh_counter <= refresh_counter + 1;
        end if;
    end process;
    
    -- Tomamos los bits 19 y 18. 
    -- Con reloj de 100MHz, esto da un refresco de aprox 95Hz (sin parpadeo visible).
    display_select <= std_logic_vector(refresh_counter(19 downto 18)); 
    
    -- PROCESO 2: LÓGICA DE DATOS A MOSTRAR
    process(bloqueado, intentos, tiempo_bloqueo)
        variable tiempo_int, decenas, unidades : integer;
    begin
        if bloqueado = '1' then
            -- CASO BLOQUEADO: Mostrar cuenta regresiva
            -- Convertimos vector a entero para poder dividir
            tiempo_int := to_integer(unsigned(tiempo_bloqueo));
            
            decenas := tiempo_int / 10;   -- División entera
            unidades := tiempo_int mod 10; -- Resto de la división
            
            digit0 <= std_logic_vector(to_unsigned(unidades, 4)); -- Dígito derecho
            digit1 <= std_logic_vector(to_unsigned(decenas, 4));  -- Dígito izquierdo
            digit2 <= "1111"; -- Apagado
            digit3 <= "1111"; -- Apagado
        else
            -- CASO NORMAL: Mostrar intentos restantes
            digit0 <= "00" & intentos; -- Muestra 3, 2, 1 o 0
            digit1 <= "1111"; -- Apagado
            digit2 <= "1111"; -- Apagado
            digit3 <= "1111"; -- Apagado
        end if;
    end process;
    
    -- PROCESO 3: MULTIPLEXOR DE ÁNODOS Y DATOS
    -- Rota el encendido de los displays basado en 'display_select'
    process(display_select, digit0, digit1, digit2, digit3)
    begin
        case display_select is
            when "00" => 
                an <= "1110";           -- Activa AN0 (derecha)
                digit_actual <= digit0; -- Muestra datos de digit0
            when "01" => 
                an <= "1101";           -- Activa AN1
                digit_actual <= digit1; 
            when "10" => 
                an <= "1011";           -- Activa AN2
                digit_actual <= digit2; 
            when "11" => 
                an <= "0111";           -- Activa AN3 (izquierda)
                digit_actual <= digit3; 
            when others => 
                an <= "1111";           -- Todos apagados (seguridad)
                digit_actual <= "1111";
        end case;
    end process;
    
    -- Salida final decodificada hacia los segmentos
    seg <= num_to_7seg(digit_actual);

end Behavioral;

-- ===============================================================================
-- MÓDULO 7: SISTEMA SEGURIDAD TOP (V6 - Reinicio de intentos al ganar)
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- DESCRIPCIÓN:
-- Este es el Módulo Principal (Top Level). Su función es instanciar (conectar)
-- todos los sub-módulos anteriores y gestionar la lógica de control global.
-- CARACTERÍSTICAS DE ESTA VERSIÓN (V6):
-- 1. Conecta los botones físicos, LEDs y Display de la tarjeta FPGA.
-- 2. Gestiona la lógica de "Game Over" (Bloqueo) y "Reset de Vidas" (al ganar o al cumplir el castigo).
entity sistema_seguridad_top is
    Port ( 
        CLK  : in STD_LOGIC;                     -- Reloj de 100 MHz
        SW   : in STD_LOGIC_VECTOR (3 downto 0); -- Switches para ingresar clave
        BTNL : in STD_LOGIC;                     -- Botón Izq: Modo Configuración / Ver clave
        BTNC : in STD_LOGIC;                     -- Botón Centro: Confirmar / Validar
        BTNR : in STD_LOGIC;                     -- Botón Der: RESET general del sistema
        LED  : out STD_LOGIC_VECTOR (15 downto 0); -- 16 LEDs para estatus y efectos
        seg  : out STD_LOGIC_VECTOR (6 downto 0);  -- Cátodos del display
        an   : out STD_LOGIC_VECTOR (3 downto 0)   -- Ánodos del display
    );
end sistema_seguridad_top;

architecture Behavioral of sistema_seguridad_top is
    -- ===========================================================================
    -- SEÑALES INTERNAS (CABLES DE INTERCONEXIÓN)
    -- ===========================================================================
    signal clave_almacenada_v      : STD_LOGIC_VECTOR(3 downto 0); -- Clave guardada en memoria
    signal tiempo_restante_v       : STD_LOGIC_VECTOR(5 downto 0); -- Tiempo del bloqueo
    signal intentos_restantes_sig  : STD_LOGIC_VECTOR(1 downto 0); -- Vidas actuales (0-3)
    
    -- Banderas de estado
    signal clave_programada_sig    : STD_LOGIC; -- '1' si ya se definió una clave
    signal sin_intentos_sig        : STD_LOGIC; -- '1' si las vidas llegaron a 0
    signal bloqueado_sig           : STD_LOGIC; -- '1' si el sistema está en castigo temporal
    
    -- Señales de la verificación
    signal acceso_concedido_sig    : STD_LOGIC; -- '1' Éxito
    signal acceso_denegado_sig     : STD_LOGIC; -- '1' Error
    signal verificando_sig         : STD_LOGIC; -- Estado
    
    -- Señales de control global
    signal iniciar_bloqueo_sig     : STD_LOGIC; -- Disparo para iniciar el temporizador
    signal reiniciar_intentos_sig  : STD_LOGIC; -- Disparo para recargar las vidas a 3
    
    -- Registros para detección de flancos
    signal sin_intentos_prev       : STD_LOGIC := '0';
    signal bloqueado_prev          : STD_LOGIC := '0';
    
    -- Señal limpia del botón central (después del debouncer)
    signal btnc_clean              : std_logic;

begin

    -- ===========================================================================
    -- INSTANCIACIÓN DE SUBMÓDULOS (CONEXIÓN DE BLOQUES)
    -- ===========================================================================
    
    -- 1. Filtro Anti-rebote para el botón central (el más usado)
    U_DB: entity work.debouncer 
        port map (clk => CLK, reset => BTNR, btn_in => BTNC, btn_out => btnc_clean);
    
    -- 2. Memoria de la contraseña (gestiona el guardado con BTNL)
    U_ALM: entity work.almacenamiento_clave 
        port map (clk => CLK, reset => BTNR, modo_config => BTNL, nueva_clave => SW, 
                  confirmar => btnc_clean, clave_almacenada => clave_almacenada_v, 
                  clave_programada => clave_programada_sig);
    
    -- 3. Contador de vidas (resta vidas con 'acceso_denegado' y recarga con 'reiniciar')
    U_CONT: entity work.contador_intentos 
        port map (clk => CLK, reset => BTNR, intento_fallido => acceso_denegado_sig, 
                  reiniciar_contador => reiniciar_intentos_sig, 
                  intentos_restantes => intentos_restantes_sig, sin_intentos => sin_intentos_sig);
    
    -- 4. Temporizador de castigo (cuenta 30s cuando se activa 'iniciar_bloqueo')
    U_TEMP: entity work.temporizador_bloqueo 
        port map (clk => CLK, reset => BTNR, iniciar_bloqueo => iniciar_bloqueo_sig, 
                  bloqueado => bloqueado_sig, tiempo_restante => tiempo_restante_v);
    
    -- 5. Comparador de claves (Cerebro lógico: decide si es éxito o error)
    U_VER: entity work.verificacion_clave 
        port map (clk => CLK, reset => BTNR, clave_ingresada => SW, clave_correcta => clave_almacenada_v, 
                  verificar => btnc_clean, bloqueado => bloqueado_sig, 
                  acceso_concedido => acceso_concedido_sig, acceso_denegado => acceso_denegado_sig, 
                  verificando => verificando_sig);
    
    -- 6. Controlador de Pantalla (Muestra vidas o tiempo restante)
    U_VIS: entity work.visualizacion_display 
        port map (clk => CLK, reset => BTNR, intentos => intentos_restantes_sig, 
                  tiempo_bloqueo => tiempo_restante_v, bloqueado => bloqueado_sig, 
                  seg => seg, an => an);

    -- ===========================================================================
    -- LÓGICA DE CONTROL DE ESTADOS (COORDINACIÓN GLOBAL)
    -- ===========================================================================
    process(CLK, BTNR) begin
        if BTNR = '1' then 
            -- Reset general de las señales de control
            sin_intentos_prev <= '0'; 
            bloqueado_prev <= '0'; 
            iniciar_bloqueo_sig <= '0'; 
            reiniciar_intentos_sig <= '0';
            
        elsif rising_edge(CLK) then
            -- Actualización de estados previos para detectar cambios (flancos)
            sin_intentos_prev <= sin_intentos_sig; 
            bloqueado_prev <= bloqueado_sig;
            
            -- REGLA 1: ACTIVACIÓN DEL BLOQUEO
            -- Si el contador de vidas llega a cero (flanco de subida de 'sin_intentos'),
            -- disparamos la señal para iniciar el temporizador de castigo.
            if sin_intentos_sig = '1' and sin_intentos_prev = '0' then 
                iniciar_bloqueo_sig <= '1'; 
            else 
                iniciar_bloqueo_sig <= '0'; 
            end if;
            
            -- REGLA 2: RECUPERACIÓN DE VIDAS (REINICIO)
            -- Se recuperan las 3 vidas en dos casos:
            -- A. El tiempo de castigo terminó (bloqueado pasa de '1' a '0').
            -- B. El usuario adivinó la clave (acceso_concedido es '1').
            if (bloqueado_sig = '0' and bloqueado_prev = '1') or (acceso_concedido_sig = '1') then 
                reiniciar_intentos_sig <= '1'; 
            else 
                reiniciar_intentos_sig <= '0'; 
            end if;
        end if;
    end process;

    -- ===========================================================================
    -- ASIGNACIÓN DE LEDS (INTERFAZ VISUAL)
    -- ===========================================================================
    process(acceso_concedido_sig, bloqueado_sig, clave_programada_sig, BTNL, intentos_restantes_sig, SW, clave_almacenada_v)
    begin
        if acceso_concedido_sig = '1' then
            -- EFECTO VICTORIA: Enciende TODOS los LEDs si la clave es correcta
            LED <= (others => '1'); 
        else
            -- ESTADO NORMAL: Apaga todo el fondo y prende LEDs específicos
            LED <= (others => '0'); 

            -- LEDs 0-3: Muestran qué switches están arriba (eco visual)
            LED(3 downto 0) <= SW;

            -- LEDs 7-9: BARRA DE VIDA (Indicador de intentos restantes)
            case intentos_restantes_sig is
                when "11" => LED(9 downto 7) <= "111"; -- 3 Vidas (●●●)
                when "10" => LED(8 downto 7) <= "11";  -- 2 Vidas ( ●●)
                when "01" => LED(7) <= '1';            -- 1 Vida  (  ●)
                when others => null;                   -- 0 Vidas (   )
            end case;

            -- LEDs de ESTADO DEL SISTEMA
            LED(14) <= bloqueado_sig;         -- LED 14: Encendido si está BLOQUEADO
            LED(13) <= clave_programada_sig;  -- LED 13: Encendido si hay clave guardada
            LED(12) <= BTNL;                  -- LED 12: Indica modo configuración activo
            
            -- TRUCO DE DEPURACIÓN:
            -- Si mantienes presionado BTNL, los LEDs 8-11 te muestran la clave secreta guardada.
            if BTNL = '1' then
                LED(11 downto 8) <= clave_almacenada_v; 
            end if;
        end if;
    end process;

end Behavioral;




-- ===============================================================================
-- MÓDULO AUXILIAR 8: BASE DE TIEMPOS (Relojes y Contadores)
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- DESCRIPCIÓN:
-- Este módulo genera dos señales temporales críticas:
-- 1. clk_1hz_enable: Un pulso que se activa una vez por segundo (para cuentas regresivas).
-- 2. refresh_cnt: Un contador rápido que sirve para dos cosas: 
--    a) Multiplexar el display de 7 segmentos.
--    b) Servir como "semilla" pseudo-aleatoria para elegir el número ganador.
entity juego_timebase is
    Port ( 
        clk            : in STD_LOGIC; -- Reloj base (100 MHz)
        reset          : in STD_LOGIC;
        clk_1hz_enable : out STD_LOGIC; -- Pulso de habilitación de 1Hz
        refresh_cnt    : out integer    -- Contador rápido (semilla/refresco)
    );
end juego_timebase;

architecture Behavioral of juego_timebase is
    -- Constantes para divisor de frecuencia (100 MHz)
    constant CLK_FREQ    : integer := 100_000_000;
    constant MAX_REFRESH : integer := 200_000; -- Velocidad de refresco del display
    
    -- Señales internas
    signal cnt_1s  : integer range 0 to CLK_FREQ := 0;
    signal cnt_ref : integer range 0 to MAX_REFRESH := 0;
begin
    process(clk, reset)
    begin
        if reset = '1' then
            cnt_1s <= 0; 
            cnt_ref <= 0; 
            clk_1hz_enable <= '0';
        elsif rising_edge(clk) then
            -- GENERADOR DE 1 HZ (Un pulso cada 100 millones de ciclos)
            if cnt_1s = CLK_FREQ - 1 then
                cnt_1s <= 0; 
                clk_1hz_enable <= '1'; -- Disparo
            else
                cnt_1s <= cnt_1s + 1; 
                clk_1hz_enable <= '0';
            end if;
            
            -- GENERADOR DE REFRESCO (Contador rápido cíclico)
            if cnt_ref = MAX_REFRESH then
                cnt_ref <= 0;
            else
                cnt_ref <= cnt_ref + 1;
            end if;
        end if;
    end process;
    
    refresh_cnt <= cnt_ref;
end Behavioral;
-- ===============================================================================
-- MÓDULO AUXILIAR 9: NÚCLEO LÓGICO (Cerebro del Juego - FSM)
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- DESCRIPCIÓN:
-- Controla toda la lógica del juego de adivinanza (0-15).
-- Gestiona los estados: Espera, Validar, Pista (Sube/Baja), Ganar (OH) y Perder (FAIL).
-- También maneja el contador de vidas (5 intentos) y captura el número aleatorio.
entity juego_fsm_core is
    Port (
        clk, reset    : in std_logic;
        btn_validar   : in std_logic; -- Botón central (ya limpio de rebotes)
        sw_in         : in std_logic_vector(3 downto 0); -- Número ingresado por usuario
        clk_1hz_en    : in std_logic; -- Pulso de 1 seg para el castigo
        refresh_val   : in integer;   -- Valor rápido para usar como número aleatorio
        
        -- Salidas hacia LEDs y Display
        leds_out      : out std_logic_vector(15 downto 0);
        state_code    : out std_logic_vector(2 downto 0); -- Código para decirle al display qué mostrar
        countdown_val : out integer range 0 to 15 -- Valor de la cuenta regresiva de castigo
    );
end juego_fsm_core;

architecture Behavioral of juego_fsm_core is
    -- Definición de estados de la FSM
    type state_type is (init, espera_ingreso, validar, oh_st, sube_st, baja_st, mostrar_fail, bloqueo_timer);
    signal state : state_type := init;
    
    -- Registros del juego
    signal numero_adivinar, intento : std_logic_vector(3 downto 0) := "0000";
    signal intentos_count : integer range 0 to 5 := 5; -- 5 Vidas
    signal cuenta_reg     : integer range 0 to 15 := 15; -- Tiempo de castigo
    
    -- Temporizador para mensajes cortos (Sube, Baja, Win)
    signal msg_timer : integer range 0 to 300_000_000 := 0;
    
    -- Detector de flanco para el botón
    signal btn_prev : std_logic := '0';
    signal btn_posedge : std_logic;
    
    -- Señales internas de salida
    signal leds_int : std_logic_vector(15 downto 0);
    signal st_code_int : std_logic_vector(2 downto 0);
begin
    -- Detector de flanco de subida del botón
    process(clk) begin if rising_edge(clk) then btn_prev <= btn_validar; end if; end process;
    btn_posedge <= btn_validar and (not btn_prev);

    process(clk, reset)
    begin
        if reset = '1' then
            state <= init; intentos_count <= 5; cuenta_reg <= 15;
            numero_adivinar <= "0000"; msg_timer <= 0;
        elsif rising_edge(clk) then
            -- Por defecto leds apagados, salvo eco de switches
            leds_int <= (others => '0');
            leds_int(3 downto 0) <= sw_in; 

            case state is
                -- ESTADO 0: INICIALIZACIÓN
                when init =>
                    intentos_count <= 5; 
                    state <= espera_ingreso;
                    
                -- ESTADO 1: ESPERANDO JUGADOR
                when espera_ingreso =>
                    st_code_int <= "000"; -- Código 0: Mostrar lo que dicen los switches
                    
                    -- Mostrar Barra de Vidas (LEDs 11 al 7)
                    if intentos_count >= 1 then leds_int(7) <= '1'; end if;
                    if intentos_count >= 2 then leds_int(8) <= '1'; end if;
                    if intentos_count >= 3 then leds_int(9) <= '1'; end if;
                    if intentos_count >= 4 then leds_int(10) <= '1'; end if;
                    if intentos_count = 5  then leds_int(11) <= '1'; end if;
                    
                    if btn_posedge = '1' then
                        intento <= sw_in;
                        -- Si es el primer intento (5 vidas), capturamos la semilla aleatoria
                        if intentos_count = 5 then
                            numero_adivinar <= std_logic_vector(to_unsigned(refresh_val mod 16, 4));
                        end if;
                        state <= validar;
                    end if;
                    
                -- ESTADO 2: VALIDACIÓN (Comparar números)
                when validar =>
                    st_code_int <= "000";
                    if intento = numero_adivinar then
                        msg_timer <= 0; state <= oh_st; -- ¡Ganó!
                    else
                        -- Falló: Restar vida y decidir pista
                        if intentos_count > 0 then intentos_count <= intentos_count - 1; end if;
                        msg_timer <= 0;
                        if unsigned(intento) < unsigned(numero_adivinar) then state <= sube_st;
                        else state <= baja_st; end if;
                    end if;
                    
                -- ESTADO 3: PISTA "SUBE"
                when sube_st =>
                    st_code_int <= "001"; -- ID 1: Mostrar "SUBE" en display
                    -- Mantener vidas visibles
                    if intentos_count >= 1 then leds_int(7) <= '1'; end if;
                    if intentos_count >= 2 then leds_int(8) <= '1'; end if;
                    if intentos_count >= 3 then leds_int(9) <= '1'; end if;
                    if intentos_count >= 4 then leds_int(10) <= '1'; end if;
                    if intentos_count = 5  then leds_int(11) <= '1'; end if;

                    -- Mostrar mensaje por 2 segundos
                    if msg_timer < 200_000_000 then msg_timer <= msg_timer + 1;
                    else
                        msg_timer <= 0;
                        if intentos_count = 0 then state <= mostrar_fail; -- Game Over
                        else state <= espera_ingreso; end if;
                    end if;

                -- ESTADO 4: PISTA "BAJA" (Misma lógica que SUBE)
                when baja_st =>
                    st_code_int <= "010"; -- ID 2: Mostrar "bAJA"
                    if intentos_count >= 1 then leds_int(7) <= '1'; end if;
                    if intentos_count >= 2 then leds_int(8) <= '1'; end if;
                    if intentos_count >= 3 then leds_int(9) <= '1'; end if;
                    if intentos_count >= 4 then leds_int(10) <= '1'; end if;
                    if intentos_count = 5  then leds_int(11) <= '1'; end if;

                    if msg_timer < 200_000_000 then msg_timer <= msg_timer + 1;
                    else
                        msg_timer <= 0;
                        if intentos_count = 0 then state <= mostrar_fail;
                        else state <= espera_ingreso; end if;
                    end if;

                -- ESTADO 5: VICTORIA ("OH")
                when oh_st =>
                    st_code_int <= "011"; -- ID 3: Mostrar "OH"
                    leds_int <= (others => '1'); -- Fiesta de LEDs
                    if msg_timer < 200_000_000 then msg_timer <= msg_timer + 1;
                    else state <= init; end if; -- Reinicia juego

                -- ESTADO 6: DERROTA ("FAIL")
                when mostrar_fail =>
                    st_code_int <= "100"; -- ID 4: Mostrar "FAIL"
                    leds_int(13) <= '1';  -- LED indicador de error
                    if msg_timer < 200_000_000 then
                        msg_timer <= msg_timer + 1; cuenta_reg <= 15;
                    else
                        msg_timer <= 0; state <= bloqueo_timer;
                    end if;

                -- ESTADO 7: BLOQUEO/CASTIGO
                when bloqueo_timer =>
                    st_code_int <= "101"; -- ID 5: Mostrar Cuenta Regresiva
                    leds_int(14) <= '1';  -- LED indicador de bloqueo
                    if clk_1hz_en = '1' then
                        if cuenta_reg > 0 then cuenta_reg <= cuenta_reg - 1;
                        else state <= init; end if; -- Reinicia al terminar castigo
                    end if;
            end case;
        end if;
    end process;
    
    leds_out <= leds_int;
    state_code <= st_code_int;
    countdown_val <= cuenta_reg;
end Behavioral;

-- ===============================================================================
-- MÓDULO AUXILIAR 10: CONTROLADOR DE DISPLAY (Visualización)
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- DESCRIPCIÓN:
-- Recibe un 'state_code' y muestra el mensaje correspondiente en los displays.
-- Códigos:
-- 000: Muestra valor de switches (Binario a Decimal 0/1 en 4 displays)
-- 001: "SUBE"
-- 010: "bAJA"
-- 011: "OH" (Victoria)
-- 100: "FAIL"
-- 101: Cuenta regresiva (00 a 15)
entity juego_display_driver is
    Port (
        clk           : in std_logic;
        reset         : in std_logic;
        refresh_cnt   : in integer; -- Contador rápido para multiplexar
        state_code    : in std_logic_vector(2 downto 0); -- Comando de qué mostrar
        sw_in         : in std_logic_vector(3 downto 0); -- Dato crudo switches
        countdown_val : in integer; -- Dato numérico del temporizador
        
        seg : out std_logic_vector(6 downto 0);
        an  : out std_logic_vector(3 downto 0)
    );
end juego_display_driver;

architecture Behavioral of juego_display_driver is
    signal an_selector : std_logic_vector(1 downto 0);
    signal data_char : std_logic_vector(4 downto 0);
    signal an_temp : std_logic_vector(3 downto 0);
    
    -- Definición de constantes para caracteres personalizados
    constant CHAR_0: std_logic_vector(4 downto 0):="00000"; constant CHAR_1: std_logic_vector(4 downto 0):="00001";
    constant CHAR_A: std_logic_vector(4 downto 0):="01010"; constant CHAR_C: std_logic_vector(4 downto 0):="01100";
    constant CHAR_E: std_logic_vector(4 downto 0):="01110"; constant CHAR_F: std_logic_vector(4 downto 0):="01111";
    constant CHAR_S: std_logic_vector(4 downto 0):="10000"; constant CHAR_U: std_logic_vector(4 downto 0):="10001";
    constant CHAR_b: std_logic_vector(4 downto 0):="10010"; constant CHAR_L: std_logic_vector(4 downto 0):="10011";
    constant CHAR_I: std_logic_vector(4 downto 0):="10100"; constant CHAR_H: std_logic_vector(4 downto 0):="10101";
    constant CHAR_O: std_logic_vector(4 downto 0):="10110"; constant CHAR_J: std_logic_vector(4 downto 0):="10111";
    constant CHAR_OFF: std_logic_vector(4 downto 0):="11100";

    -- Función decodificadora: Convierte ID de carácter a segmentos (gfedcba)
    function char_to_7seg(val: std_logic_vector(4 downto 0)) return STD_LOGIC_VECTOR is
    begin
        case val is
            -- Números básicos
            when "00000" => return "0000001"; when "00001" => return "1001111";
            -- ... (Espacio para num 2-9 si fuera necesario) ...
            -- Letras para mensajes
            when "01010" => return "0001000"; -- A
            when "10010" => return "1100000"; -- b
            when "01110" => return "0110000"; -- E
            when "01111" => return "0111000"; -- F
            when "10000" => return "0100100"; -- S
            when "10001" => return "1000001"; -- U
            when "10011" => return "1110001"; -- L
            when "10100" => return "1001111"; -- I
            when "10101" => return "1001000"; -- H
            when "10110" => return "0000001"; -- O
            when "10111" => return "1000011"; -- J
            when others => return "1111111";  -- Apagado
        end case;
    end function;

begin
    -- Selección de ánodo basado en bits altos del contador de refresco
    an_selector <= std_logic_vector(to_unsigned((refresh_cnt / 50000) mod 4, 2));

    process(an_selector, state_code, sw_in, countdown_val)
    begin
        data_char <= CHAR_OFF; an_temp <= "1111";
        
        -- MÁQUINA DE ESTADO DE VISUALIZACIÓN
        -- Dependiendo del ánodo activo y el 'state_code', elegimos qué letra mostrar.
        case an_selector is
            when "00" => an_temp<="1110"; -- Dígito 0 (Derecha)
                if state_code="001" then data_char <= CHAR_E;       -- SUB(E)
                elsif state_code="010" then data_char <= CHAR_A;    -- BAJ(A)
                elsif state_code="100" then data_char <= CHAR_L;    -- FAI(L)
                elsif state_code="101" then data_char <= "0" & std_logic_vector(to_unsigned(countdown_val mod 10, 4));
                elsif state_code="000" then 
                    if sw_in(0)='1' then data_char<=CHAR_1; else data_char<=CHAR_0; end if;
                end if;
                
            when "01" => an_temp<="1101"; -- Dígito 1
                if state_code="001" then data_char <= CHAR_b;       -- SU(b)E
                elsif state_code="010" then data_char <= CHAR_J;    -- BA(J)A
                elsif state_code="100" then data_char <= CHAR_I;    -- FA(I)L
                elsif state_code="101" then data_char <= "0" & std_logic_vector(to_unsigned(countdown_val / 10, 4));
                elsif state_code="000" then 
                    if sw_in(1)='1' then data_char<=CHAR_1; else data_char<=CHAR_0; end if;
                end if;
                
            when "10" => an_temp<="1011"; -- Dígito 2
                if state_code="001" then data_char <= CHAR_U;       -- S(U)BE
                elsif state_code="010" then data_char <= CHAR_A;    -- B(A)JA
                elsif state_code="100" then data_char <= CHAR_A;    -- F(A)IL
                elsif state_code="000" then 
                    if sw_in(2)='1' then data_char<=CHAR_1; else data_char<=CHAR_0; end if;
                end if;
                
            when "11" => an_temp<="0111"; -- Dígito 3 (Izquierda)
                if state_code="001" then data_char <= CHAR_S;       -- (S)UBE
                elsif state_code="010" then data_char <= CHAR_b;    -- (b)AJA
                elsif state_code="100" then data_char <= CHAR_F;    -- (F)AIL
                elsif state_code="000" then 
                    if sw_in(3)='1' then data_char<=CHAR_1; else data_char<=CHAR_0; end if;
                end if;
                
            when others => an_temp<="1111";
        end case;
    end process;

    -- Salida final a segmentos
    -- Nota: Override especial para mostrar "OH" (usando segmentos crudos para la O y H)
    seg <= "1001000" when (state_code="011" and an_selector="00") else -- H
           "0000001" when (state_code="011" and an_selector="01") else -- O
           "1111111" when (state_code="011") else -- Apagar los otros dos dígitos
           char_to_7seg(data_char);
           
    an <= an_temp;
end Behavioral;

-- ===============================================================================
-- MÓDULO 11 (TOP): JUEGO ADIVINANZA (Integración)
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- DESCRIPCIÓN:
-- Módulo Top-Level del Juego de Adivinanza.
-- Interconecta:
-- 1. Base de Tiempos (Relojes)
-- 2. Núcleo Lógico (Reglas del juego)
-- 3. Controlador de Display (Interfaz visual)
entity juego_adivinanza is
    Port (
        clk          : in std_logic;
        reset        : in std_logic;
        BTNC_validar : in std_logic; -- Botón de acción
        SW_in        : in std_logic_vector(3 downto 0); -- Switches de entrada
        LED_out      : out std_logic_vector(15 downto 0); -- Feedback en LEDs
        seg          : out std_logic_vector(6 downto 0);  -- Salida display
        an           : out std_logic_vector(3 downto 0)   -- Selector display
    );
end juego_adivinanza;

architecture Structural of juego_adivinanza is
    -- Señales internas (Cables)
    signal s_clk_1hz    : std_logic;
    signal s_refresh    : integer;
    signal s_state_code : std_logic_vector(2 downto 0);
    signal s_countdown  : integer;
    
begin
    -- INSTANCIA 1: BASE DE TIEMPO
    -- Genera los pulsos de reloj necesarios para lógica y visualización
    U_TIME: entity work.juego_timebase port map (
        clk => clk, reset => reset, 
        clk_1hz_enable => s_clk_1hz, refresh_cnt => s_refresh
    );

    -- INSTANCIA 2: NÚCLEO DEL JUEGO
    -- Recibe las entradas, procesa reglas y define estados
    U_CORE: entity work.juego_fsm_core port map (
        clk => clk, reset => reset, 
        btn_validar => BTNC_validar, 
        sw_in => SW_in, 
        clk_1hz_en => s_clk_1hz, refresh_val => s_refresh,
        leds_out => LED_out, 
        state_code => s_state_code, 
        countdown_val => s_countdown
    );

    -- INSTANCIA 3: CONTROL DE PANTALLA
    -- Traduce el estado interno a mensajes en el display
    U_DISP: entity work.juego_display_driver port map (
        clk => clk, reset => reset,
        refresh_cnt => s_refresh,
        state_code => s_state_code,
        sw_in => SW_in,
        countdown_val => s_countdown,
        seg => seg, an => an
    );

end Structural;

-- ===============================================================================
-- MÓDULO 12: TOP GAME (INTEGRACIÓN FINAL CON EFECTO DE CARGA LENTA)
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- DESCRIPCIÓN:
-- Este es el módulo SUPERIOR de todo el proyecto.
-- FUNCIONES:
-- 1. Integra el Proyecto de Seguridad y el Proyecto de Juego en un solo chip.
-- 2. Usa el Switch 4 (SW4) para seleccionar qué proyecto usar.
-- 3. Implementa un "Efecto de Transición": Al cambiar de modo, bloquea el sistema
--    durante 1 segundo y muestra una animación de carga en los LEDs (6, 7, 8).
entity top_game is
    Port ( 
        clk      : in std_logic;                     -- Reloj de 100 MHz
        SW       : in std_logic_vector(4 downto 0);  -- SW4=Selector, SW3-0=Datos
        BTNC     : in std_logic;                     -- Botón de acción
        BTNL     : in std_logic;                     -- Botón configuración (Seguridad)
        BTNR     : in std_logic;                     -- Reset Global
        LEDS     : out std_logic_vector(15 downto 0);-- Salida física a LEDs Basys3
        DISP_SEG : out std_logic_vector(6 downto 0); -- Cátodos Display
        DISP_AN  : out std_logic_vector(3 downto 0)  -- Ánodos Display
    );
end top_game;

architecture Behavioral of top_game is
    -- Señales de control global
    signal selector_modo : std_logic; -- '0' = Seguridad, '1' = Juego
    signal reset_global  : std_logic;
    signal btnc_clean    : std_logic; -- Señal limpia del botón central
    signal sw_data       : std_logic_vector(3 downto 0); -- Datos de entrada (SW 0-3)
    
    -- CABLES DE SALIDA INTERNA (Lo que "dice" cada submódulo)
    signal seg_out_LEDS, juego_out_LEDS       : std_logic_vector(15 downto 0);
    signal seg_out_DISP_SEG, juego_out_seg    : std_logic_vector(6 downto 0);
    signal seg_out_DISP_AN, juego_out_an      : std_logic_vector(3 downto 0);
    
    -- VARIABLES PARA EL EFECTO DE CARGA (LOADING)
    signal sw_mode_prev   : std_logic := '0'; -- Para detectar cuando cambias el switch
    signal loading_active : std_logic := '0'; -- Bandera: '1' si estamos en transición
    
    -- TEMPORIZADOR MAESTRO DE 1 SEGUNDO
    -- 100 MHz * 1 seg = 100,000,000 ciclos
    signal loading_timer_max     : integer := 100_000_000; 
    signal loading_timer_current : integer range 0 to 100_000_000 := 0; 

    -- CONTROL DE ANIMACIÓN DE LEDS
    -- Contador simple (0, 1, 2) para encender LED 6, 7 y 8 en secuencia
    signal seq_led_counter : integer range 0 to 2 := 0; 
    
    -- DIVISOR DE VELOCIDAD VISUAL
    -- Queremos que los LEDs se muevan lento para que el ojo lo vea.
    -- 15,000,000 ciclos = 0.15 segundos por salto (aprox 6 saltos/segundo).
    signal seq_clk_divider       : integer range 0 to 15_000_000 := 0; 
    constant SEQ_SPEED_TICKS     : integer := 15_000_000; 

begin
    -- Asignaciones de entradas físicas a señales internas
    selector_modo <= SW(4);        -- El Switch 4 decide quién manda
    sw_data       <= SW(3 downto 0); -- Los Switches 0-3 son para datos
    reset_global  <= BTNR;           -- El botón derecho resetea todo
    
    -- ===========================================================================
    -- INSTANCIACIÓN DE PROYECTOS (Conectamos los módulos anteriores)
    -- ===========================================================================
    
    -- 1. Debouncer Global (Limpia el botón central para ambos proyectos)
    U_DB: entity work.debouncer 
        port map (clk => clk, reset => reset_global, btn_in => BTNC, btn_out => btnc_clean);
    
    -- 2. PROYECTO DE SEGURIDAD (Módulos 1 al 7)
    U_SEG: entity work.sistema_seguridad_top 
        port map (
            CLK => clk, SW => sw_data, BTNL => BTNL, BTNC => btnc_clean, BTNR => reset_global, 
            LED => seg_out_LEDS, seg => seg_out_DISP_SEG, an => seg_out_DISP_AN
        );
    
    -- 3. PROYECTO DE JUEGO ADIVINANZA (Módulo 8)
    U_JUE: entity work.juego_adivinanza 
        port map (
            clk => clk, reset => reset_global, SW_in => sw_data, BTNC_validar => btnc_clean, 
            LED_out => juego_out_LEDS, seg => juego_out_seg, an => juego_out_an
        );

    -- ===========================================================================
    -- PROCESO DE CONTROL DE TRANSICIÓN (EFECTO LOADING)
    -- ===========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            -- 1. DETECCIÓN DE CAMBIO (¿Moviste el Switch 4?)
            if sw_mode_prev /= selector_modo then
                loading_active <= '1';          -- Activar modo carga
                loading_timer_current <= loading_timer_max; -- Cargar 1 segundo
                seq_led_counter <= 0;           -- Reiniciar animación
                seq_clk_divider <= 0;           -- Reiniciar divisor
            end if;
            sw_mode_prev <= selector_modo; -- Guardar estado actual
            
            -- 2. EJECUCIÓN DEL EFECTO
            if loading_active = '1' then
                if loading_timer_current > 0 then
                    loading_timer_current <= loading_timer_current - 1; -- Cuenta regresiva
                    
                    -- ANIMACIÓN DE LEDS (Lentitud controlada)
                    if seq_clk_divider = SEQ_SPEED_TICKS then
                        seq_clk_divider <= 0;
                        -- Avanza al siguiente LED (0 -> 1 -> 2 -> 0 ...)
                        seq_led_counter <= (seq_led_counter + 1) mod 3; 
                    else
                        seq_clk_divider <= seq_clk_divider + 1;
                    end if;
                else
                    loading_active <= '0'; -- ¡Tiempo cumplido! Volver al programa normal
                end if;
            end if;
        end if;
    end process;

    -- ===========================================================================
    -- MULTIPLEXOR DE SALIDA (¿Quién controla los LEDs y Displays?)
    -- ===========================================================================
    process(selector_modo, loading_active, seq_led_counter, 
            seg_out_LEDS, seg_out_DISP_SEG, seg_out_DISP_AN, 
            juego_out_LEDS, juego_out_seg, juego_out_an)
        variable temp_leds : std_logic_vector(15 downto 0);
    begin
        -- PRIORIDAD 1: MODO CARGA (Si estamos en transición, ignorar todo lo demás)
        if loading_active = '1' then
            temp_leds := (others => '0'); 
            
            -- Efecto "Auto Fantástico" pequeño en LEDs 6, 7 y 8
            case seq_led_counter is
                when 0 => temp_leds(6) := '1';
                when 1 => temp_leds(7) := '1';
                when 2 => temp_leds(8) := '1';
                when others => null;
            end case;
            LEDS <= temp_leds;
            
            DISP_SEG <= "1111111"; -- Apagar pantalla durante la carga
            DISP_AN <= "1111";     
            
        -- PRIORIDAD 2: FUNCIONAMIENTO NORMAL
        else
            if selector_modo = '0' then
                -- MODO SEGURIDAD
                LEDS <= seg_out_LEDS;
                DISP_SEG <= seg_out_DISP_SEG;
                DISP_AN <= seg_out_DISP_AN;
            else
                -- MODO JUEGO
                LEDS <= juego_out_LEDS;
                DISP_SEG <= juego_out_seg;
                DISP_AN <= juego_out_an;
            end if;
        end if;
    end process;

end Behavioral;