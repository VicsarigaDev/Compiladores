#include <iostream>
#include <string>
#include <cctype>

class NumberValidator {
private:
    int currentState;

    // Función auxiliar para clasificar la entrada
    enum class InputType { DIGIT, POINT, EXP, SIGN, OTHER };

    InputType getInputType(char c) {
        if (isdigit(c)) return InputType::DIGIT;
        if (c == '.') return InputType::POINT;
        if (c == 'E' || c == 'e') return InputType::EXP;
        if (c == '+' || c == '-') return InputType::SIGN;
        return InputType::OTHER;
    }

public:
    NumberValidator() : currentState(12) {}

    bool validate(std::string input) {
        currentState = 12; // Reiniciar al estado inicial "start"
        
        for (char c : input) {
            InputType type = getInputType(c);

            switch (currentState) {
                case 12:
                    if (type == InputType::DIGIT) currentState = 13;
                    else return false; // Error: debe empezar con dígito
                    break;
                case 13:
                    if (type == InputType::DIGIT) currentState = 13;
                    else if (type == InputType::POINT) currentState = 14;
                    else if (type == InputType::EXP) currentState = 16;
                    else currentState = 20; // Aceptación (other)
                    break;
                case 14:
                    if (type == InputType::DIGIT) currentState = 15;
                    else return false;
                    break;
                case 15:
                    if (type == InputType::DIGIT) currentState = 15;
                    else if (type == InputType::EXP) currentState = 16;
                    else currentState = 21; // Aceptación (other)
                    break;
                case 16:
                    if (type == InputType::SIGN) currentState = 17;
                    else if (type == InputType::DIGIT) currentState = 18;
                    else return false;
                    break;
                case 17:
                    if (type == InputType::DIGIT) currentState = 18;
                    else return false;
                    break;
                case 18:
                    if (type == InputType::DIGIT) currentState = 18;
                    else currentState = 19; // Aceptación (other)
                    break;
            }
            
            // Si caemos en un estado final de "other", terminamos la validación
            if (currentState == 19 || currentState == 20 || currentState == 21) return true;
        }

        // Al final de la cadena, verificamos si terminamos en un estado válido
        return (currentState == 13 || currentState == 15 || currentState == 18 || 
                currentState == 19 || currentState == 20 || currentState == 21);
    }
};

int main() {
    NumberValidator validator;
    std::string test;

    std::cout << "Introduce un numero para validar: ";
    std::cin >> test;

    if (validator.validate(test)) {
        std::cout << "Resultado: VALIDO" << std::endl;
    } else {
        std::cout << "Resultado: NO VALIDO" << std::endl;
    }

    return 0;
}